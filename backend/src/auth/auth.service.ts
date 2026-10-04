import {
  Injectable,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) throw new ConflictException('El correo ya está registrado');

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: { email: dto.email, name: dto.name, passwordHash },
    });
    return this.buildTokenResponse(user.id, user.email, user.role);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user) throw new UnauthorizedException('Credenciales inválidas');

    // NUEVA VALIDACIÓN: Si el usuario existe pero no tiene contraseña, es un usuario de Google
    if (!user.passwordHash) {
      throw new UnauthorizedException('Esta cuenta está vinculada a Google. Por favor, inicia sesión con Google.');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Credenciales inválidas');

    return this.buildTokenResponse(user.id, user.email, user.role);
  }

  /**
   * Procesa el inicio de sesión o registro automático vía Google OAuth.
   * @param {any} googleUser - Perfil extraído por GoogleStrategy.
   * @returns {Promise<{accessToken: string}>} Token JWT de acceso de MXGuide.
   */
  async googleLogin(googleUser: any) {
    if (!googleUser) {
      throw new UnauthorizedException('No se recibió información de Google');
    }

    const { email, name, googleId } = googleUser;

    let user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      // El usuario es totalmente nuevo, lo registramos.
      user = await this.prisma.user.create({
        data: {
          email,
          name,
          googleId,
          // passwordHash queda null automáticamente
        },
      });
    } else if (!user.googleId) {
      // El usuario existía por registro tradicional, vinculamos su cuenta de Google.
      user = await this.prisma.user.update({
        where: { email },
        data: { googleId },
      });
    }

    return this.buildTokenResponse(user.id, user.email, user.role);
  }

  async me(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });
  }

  private buildTokenResponse(sub: string, email: string, role: string) {
    const accessToken = this.jwt.sign({ sub, email, role });
    return { accessToken };
  }
}
