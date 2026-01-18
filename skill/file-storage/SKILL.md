# File Storage & Processing

> **Sources**: [AWS S3 SDK](https://github.com/aws/aws-sdk-js-v3), [Cloudflare R2](https://developers.cloudflare.com/r2/), [Sharp](https://github.com/lovell/sharp) (29k⭐)
> **Auto-trigger**: Files containing S3, R2, file uploads, presigned URLs, image processing, `sharp`, blob storage

---

## S3 / R2 Setup

### Installation
```bash
npm install @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
```

### Client Configuration
```typescript
// lib/s3.ts
import { S3Client } from '@aws-sdk/client-s3';

// AWS S3
export const s3Client = new S3Client({
  region: process.env.AWS_REGION!,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
});

// Cloudflare R2 (S3-compatible)
export const r2Client = new S3Client({
  region: 'auto',
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
});

export const BUCKET_NAME = process.env.S3_BUCKET_NAME!;
```

---

## Direct Upload (Small Files)

### Upload from Server
```typescript
// lib/storage.ts
import { PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { s3Client, BUCKET_NAME } from './s3';
import { randomUUID } from 'crypto';

interface UploadOptions {
  folder?: string;
  contentType?: string;
  metadata?: Record<string, string>;
}

export async function uploadFile(
  buffer: Buffer,
  filename: string,
  options: UploadOptions = {}
): Promise<string> {
  const { folder = 'uploads', contentType, metadata } = options;
  
  // Generate unique key
  const ext = filename.split('.').pop() || '';
  const key = `${folder}/${randomUUID()}.${ext}`;

  await s3Client.send(
    new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: buffer,
      ContentType: contentType || getMimeType(ext),
      Metadata: metadata,
      // For public files
      // ACL: 'public-read',
    })
  );

  return key;
}

export async function getFile(key: string): Promise<Buffer> {
  const response = await s3Client.send(
    new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
    })
  );

  return Buffer.from(await response.Body!.transformToByteArray());
}

export async function deleteFile(key: string): Promise<void> {
  await s3Client.send(
    new DeleteObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
    })
  );
}

function getMimeType(ext: string): string {
  const mimeTypes: Record<string, string> = {
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    gif: 'image/gif',
    webp: 'image/webp',
    pdf: 'application/pdf',
    mp4: 'video/mp4',
  };
  return mimeTypes[ext.toLowerCase()] || 'application/octet-stream';
}
```

### API Route
```typescript
// app/api/upload/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { uploadFile } from '@/lib/storage';
import { auth } from '@/lib/auth';

const MAX_SIZE = 10 * 1024 * 1024; // 10MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const formData = await req.formData();
  const file = formData.get('file') as File | null;

  if (!file) {
    return NextResponse.json({ error: 'No file provided' }, { status: 400 });
  }

  if (file.size > MAX_SIZE) {
    return NextResponse.json({ error: 'File too large' }, { status: 400 });
  }

  if (!ALLOWED_TYPES.includes(file.type)) {
    return NextResponse.json({ error: 'Invalid file type' }, { status: 400 });
  }

  const buffer = Buffer.from(await file.arrayBuffer());
  const key = await uploadFile(buffer, file.name, {
    folder: `users/${session.user.id}`,
    contentType: file.type,
    metadata: {
      uploadedBy: session.user.id,
      originalName: file.name,
    },
  });

  return NextResponse.json({
    key,
    url: `${process.env.CDN_URL}/${key}`,
  });
}
```

---

## Presigned URLs (Large Files / Direct-to-S3)

### Generate Upload URL
```typescript
// lib/presigned.ts
import { PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { s3Client, BUCKET_NAME } from './s3';
import { randomUUID } from 'crypto';

interface PresignedUploadOptions {
  folder?: string;
  contentType: string;
  maxSizeBytes?: number;
  expiresIn?: number; // seconds
}

export async function getPresignedUploadUrl(
  options: PresignedUploadOptions
): Promise<{ uploadUrl: string; key: string }> {
  const {
    folder = 'uploads',
    contentType,
    expiresIn = 3600, // 1 hour
  } = options;

  const ext = contentType.split('/')[1] || 'bin';
  const key = `${folder}/${randomUUID()}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: BUCKET_NAME,
    Key: key,
    ContentType: contentType,
  });

  const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn });

  return { uploadUrl, key };
}

export async function getPresignedDownloadUrl(
  key: string,
  expiresIn = 3600
): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: BUCKET_NAME,
    Key: key,
  });

  return getSignedUrl(s3Client, command, { expiresIn });
}
```

### API Routes
```typescript
// app/api/upload/presigned/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getPresignedUploadUrl } from '@/lib/presigned';
import { auth } from '@/lib/auth';

export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { contentType, filename } = await req.json();

  // Validate content type
  const allowedTypes = ['image/jpeg', 'image/png', 'video/mp4', 'application/pdf'];
  if (!allowedTypes.includes(contentType)) {
    return NextResponse.json({ error: 'Invalid file type' }, { status: 400 });
  }

  const { uploadUrl, key } = await getPresignedUploadUrl({
    folder: `users/${session.user.id}`,
    contentType,
  });

  // Store pending upload for validation
  await db.pendingUpload.create({
    data: {
      key,
      userId: session.user.id,
      contentType,
      originalFilename: filename,
      expiresAt: new Date(Date.now() + 3600 * 1000),
    },
  });

  return NextResponse.json({ uploadUrl, key });
}

// Confirm upload completed
// app/api/upload/confirm/route.ts
export async function POST(req: NextRequest) {
  const session = await auth();
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { key } = await req.json();

  // Verify upload exists and belongs to user
  const pending = await db.pendingUpload.findFirst({
    where: {
      key,
      userId: session.user.id,
      expiresAt: { gt: new Date() },
    },
  });

  if (!pending) {
    return NextResponse.json({ error: 'Invalid upload' }, { status: 400 });
  }

  // Verify file exists in S3
  try {
    await s3Client.send(new HeadObjectCommand({ Bucket: BUCKET_NAME, Key: key }));
  } catch {
    return NextResponse.json({ error: 'File not found' }, { status: 400 });
  }

  // Create permanent record
  const file = await db.file.create({
    data: {
      key,
      userId: session.user.id,
      contentType: pending.contentType,
      originalFilename: pending.originalFilename,
    },
  });

  await db.pendingUpload.delete({ where: { id: pending.id } });

  return NextResponse.json({ file });
}
```

### Client-Side Upload
```typescript
// hooks/useUpload.ts
'use client';

import { useState } from 'react';

interface UploadProgress {
  loaded: number;
  total: number;
  percentage: number;
}

export function usePresignedUpload() {
  const [progress, setProgress] = useState<UploadProgress | null>(null);
  const [uploading, setUploading] = useState(false);

  const upload = async (file: File): Promise<string> => {
    setUploading(true);
    setProgress(null);

    try {
      // Get presigned URL
      const response = await fetch('/api/upload/presigned', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contentType: file.type,
          filename: file.name,
        }),
      });

      if (!response.ok) throw new Error('Failed to get upload URL');
      const { uploadUrl, key } = await response.json();

      // Upload directly to S3
      await new Promise<void>((resolve, reject) => {
        const xhr = new XMLHttpRequest();

        xhr.upload.addEventListener('progress', (e) => {
          if (e.lengthComputable) {
            setProgress({
              loaded: e.loaded,
              total: e.total,
              percentage: Math.round((e.loaded / e.total) * 100),
            });
          }
        });

        xhr.addEventListener('load', () => {
          if (xhr.status >= 200 && xhr.status < 300) {
            resolve();
          } else {
            reject(new Error('Upload failed'));
          }
        });

        xhr.addEventListener('error', () => reject(new Error('Upload failed')));

        xhr.open('PUT', uploadUrl);
        xhr.setRequestHeader('Content-Type', file.type);
        xhr.send(file);
      });

      // Confirm upload
      await fetch('/api/upload/confirm', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key }),
      });

      return key;
    } finally {
      setUploading(false);
    }
  };

  return { upload, progress, uploading };
}
```

---

## Chunked Uploads (Large Files)

### Multipart Upload
```typescript
// lib/multipart.ts
import {
  CreateMultipartUploadCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand,
} from '@aws-sdk/client-s3';
import { s3Client, BUCKET_NAME } from './s3';

const CHUNK_SIZE = 10 * 1024 * 1024; // 10MB chunks

interface MultipartUpload {
  key: string;
  uploadId: string;
}

export async function initiateMultipartUpload(
  key: string,
  contentType: string
): Promise<MultipartUpload> {
  const response = await s3Client.send(
    new CreateMultipartUploadCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      ContentType: contentType,
    })
  );

  return {
    key,
    uploadId: response.UploadId!,
  };
}

export async function uploadPart(
  key: string,
  uploadId: string,
  partNumber: number,
  body: Buffer
): Promise<{ ETag: string; PartNumber: number }> {
  const response = await s3Client.send(
    new UploadPartCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      UploadId: uploadId,
      PartNumber: partNumber,
      Body: body,
    })
  );

  return {
    ETag: response.ETag!,
    PartNumber: partNumber,
  };
}

export async function completeMultipartUpload(
  key: string,
  uploadId: string,
  parts: Array<{ ETag: string; PartNumber: number }>
): Promise<void> {
  await s3Client.send(
    new CompleteMultipartUploadCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      UploadId: uploadId,
      MultipartUpload: {
        Parts: parts.sort((a, b) => a.PartNumber - b.PartNumber),
      },
    })
  );
}

export async function abortMultipartUpload(
  key: string,
  uploadId: string
): Promise<void> {
  await s3Client.send(
    new AbortMultipartUploadCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      UploadId: uploadId,
    })
  );
}
```

---

## Image Processing with Sharp

### Installation
```bash
npm install sharp
```

### Image Optimization
```typescript
// lib/image-processing.ts
import sharp from 'sharp';

interface ProcessOptions {
  maxWidth?: number;
  maxHeight?: number;
  quality?: number;
  format?: 'jpeg' | 'png' | 'webp' | 'avif';
}

export async function processImage(
  buffer: Buffer,
  options: ProcessOptions = {}
): Promise<Buffer> {
  const {
    maxWidth = 2000,
    maxHeight = 2000,
    quality = 80,
    format = 'webp',
  } = options;

  let pipeline = sharp(buffer)
    .rotate() // Auto-rotate based on EXIF
    .resize(maxWidth, maxHeight, {
      fit: 'inside',
      withoutEnlargement: true,
    });

  switch (format) {
    case 'jpeg':
      pipeline = pipeline.jpeg({ quality, mozjpeg: true });
      break;
    case 'png':
      pipeline = pipeline.png({ quality, compressionLevel: 9 });
      break;
    case 'webp':
      pipeline = pipeline.webp({ quality });
      break;
    case 'avif':
      pipeline = pipeline.avif({ quality });
      break;
  }

  return pipeline.toBuffer();
}

// Generate responsive image set
export async function generateResponsiveImages(
  buffer: Buffer
): Promise<Map<string, Buffer>> {
  const sizes = [320, 640, 1024, 1920];
  const results = new Map<string, Buffer>();

  for (const width of sizes) {
    const processed = await sharp(buffer)
      .resize(width, null, { withoutEnlargement: true })
      .webp({ quality: 80 })
      .toBuffer();

    results.set(`${width}w`, processed);
  }

  return results;
}

// Generate thumbnail
export async function generateThumbnail(
  buffer: Buffer,
  size = 200
): Promise<Buffer> {
  return sharp(buffer)
    .resize(size, size, {
      fit: 'cover',
      position: 'centre',
    })
    .webp({ quality: 70 })
    .toBuffer();
}

// Extract metadata
export async function getImageMetadata(buffer: Buffer) {
  const metadata = await sharp(buffer).metadata();
  return {
    width: metadata.width,
    height: metadata.height,
    format: metadata.format,
    size: buffer.length,
    hasAlpha: metadata.hasAlpha,
  };
}

// Add watermark
export async function addWatermark(
  buffer: Buffer,
  watermarkBuffer: Buffer
): Promise<Buffer> {
  return sharp(buffer)
    .composite([
      {
        input: watermarkBuffer,
        gravity: 'southeast',
        blend: 'over',
      },
    ])
    .toBuffer();
}
```

### Processing Pipeline
```typescript
// lib/upload-pipeline.ts
import { uploadFile } from './storage';
import { processImage, generateThumbnail, getImageMetadata } from './image-processing';

interface ProcessedUpload {
  original: string;
  optimized: string;
  thumbnail: string;
  metadata: {
    width: number;
    height: number;
    format: string;
  };
}

export async function processAndUploadImage(
  buffer: Buffer,
  filename: string,
  userId: string
): Promise<ProcessedUpload> {
  const folder = `users/${userId}/images`;

  // Get metadata
  const metadata = await getImageMetadata(buffer);

  // Process images in parallel
  const [optimized, thumbnail] = await Promise.all([
    processImage(buffer, { format: 'webp', quality: 85 }),
    generateThumbnail(buffer, 300),
  ]);

  // Upload all versions in parallel
  const [originalKey, optimizedKey, thumbnailKey] = await Promise.all([
    uploadFile(buffer, filename, { folder: `${folder}/original` }),
    uploadFile(optimized, filename.replace(/\.\w+$/, '.webp'), {
      folder: `${folder}/optimized`,
    }),
    uploadFile(thumbnail, filename.replace(/\.\w+$/, '-thumb.webp'), {
      folder: `${folder}/thumbnails`,
    }),
  ]);

  return {
    original: originalKey,
    optimized: optimizedKey,
    thumbnail: thumbnailKey,
    metadata: {
      width: metadata.width!,
      height: metadata.height!,
      format: metadata.format!,
    },
  };
}
```

---

## CDN Integration

### CloudFront / R2
```typescript
// lib/cdn.ts
const CDN_URL = process.env.CDN_URL!; // e.g., https://cdn.example.com

export function getCdnUrl(key: string): string {
  return `${CDN_URL}/${key}`;
}

// Signed URLs for private content
import { getSignedUrl } from '@aws-sdk/cloudfront-signer';

export function getSignedCdnUrl(key: string, expiresIn = 3600): string {
  const url = `${CDN_URL}/${key}`;
  
  return getSignedUrl({
    url,
    keyPairId: process.env.CLOUDFRONT_KEY_PAIR_ID!,
    privateKey: process.env.CLOUDFRONT_PRIVATE_KEY!,
    dateLessThan: new Date(Date.now() + expiresIn * 1000).toISOString(),
  });
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Trust user-provided filenames
const key = `uploads/${file.name}`; // Path traversal risk!

// ✅ CORRECT: Generate safe keys
const key = `uploads/${randomUUID()}.${getSafeExtension(file.type)}`;

// ❌ NEVER: Skip content type validation
await uploadFile(buffer, file.name); // Could upload malicious files

// ✅ CORRECT: Validate type
if (!ALLOWED_TYPES.includes(file.type)) {
  throw new Error('Invalid file type');
}

// ❌ NEVER: Store files without size limits
const file = await req.formData(); // Unlimited size!

// ✅ CORRECT: Enforce limits
if (file.size > MAX_SIZE) {
  throw new Error('File too large');
}

// ❌ NEVER: Return S3 keys directly as URLs
return { url: key }; // Not a valid URL!

// ✅ CORRECT: Return CDN URL
return { url: getCdnUrl(key) };

// ❌ NEVER: Keep failed uploads
try {
  await processImage(buffer);
} catch {
  // Uploaded file left orphaned!
}

// ✅ CORRECT: Clean up on failure
const key = await uploadFile(buffer, filename);
try {
  await processImage(buffer);
} catch {
  await deleteFile(key);
  throw error;
}
```

---

## Quick Reference

### S3 Storage Classes
| Class | Use Case | Cost |
|-------|----------|------|
| Standard | Frequently accessed | $$$ |
| Intelligent-Tiering | Unknown access pattern | $$ |
| Glacier Instant | Archive, instant access | $ |
| Glacier Deep | Long-term archive | ¢ |

### Image Format Comparison
| Format | Best For | Browser Support |
|--------|----------|-----------------|
| WebP | General use | All modern |
| AVIF | Best compression | Chrome, Firefox |
| JPEG | Photos, no alpha | Universal |
| PNG | Transparency, graphics | Universal |

### Sharp Operations
| Method | Purpose |
|--------|---------|
| `.resize()` | Resize image |
| `.rotate()` | Rotate/auto-orient |
| `.webp()` | Convert to WebP |
| `.composite()` | Overlay/watermark |
| `.blur()` | Apply blur |
| `.sharpen()` | Sharpen |
| `.metadata()` | Get image info |

### Checklist
- [ ] Validate file type (MIME + magic bytes)
- [ ] Enforce size limits
- [ ] Generate safe filenames (UUID)
- [ ] Process images (resize, optimize)
- [ ] Use presigned URLs for large files
- [ ] CDN for delivery
- [ ] Clean up failed uploads
- [ ] Organize by user/date in folders
- [ ] Set appropriate cache headers
