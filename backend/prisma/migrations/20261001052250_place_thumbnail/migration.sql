-- CreateTable
CREATE TABLE "PlaceThumbnail" (
    "placeId" TEXT NOT NULL,
    "mime" TEXT NOT NULL,
    "data" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlaceThumbnail_pkey" PRIMARY KEY ("placeId")
);

-- AddForeignKey
ALTER TABLE "PlaceThumbnail" ADD CONSTRAINT "PlaceThumbnail_placeId_fkey" FOREIGN KEY ("placeId") REFERENCES "Place"("id") ON DELETE CASCADE ON UPDATE CASCADE;
