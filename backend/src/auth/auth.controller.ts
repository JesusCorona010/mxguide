import { Controller, Post, Get, Body, UseGuards, Request } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Request() req) {
    return this.authService.me(req.user.userId);
  }

  /**
   * Inicia el flujo de autenticación con Google.
   */
  @Get('google')
  @UseGuards(AuthGuard('google'))
  async googleAuth() {
    // La lógica interna de Passport redirige automáticamente al login de Google.
  }

  /**
   * Endpoint de retorno tras la autenticación exitosa en Google.
   */
  @Get('google/callback')
  @UseGuards(AuthGuard('google'))
  async googleAuthRedirect(@Request() req) {
    // Passport inyecta el perfil validado en req.user
    return this.authService.googleLogin(req.user);
  }
}
