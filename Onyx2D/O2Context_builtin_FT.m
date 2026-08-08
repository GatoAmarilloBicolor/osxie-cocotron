#import <Onyx2D/O2Context_builtin_FT.h>
#import <Onyx2D/O2Font_freetype.h>
#import <Onyx2D/O2GraphicsState.h>
#import <Onyx2D/O2Image.h>
#import <Onyx2D/O2Paint_color.h>
#import <Onyx2D/O2Surface.h>
#import <string.h>

@implementation O2Context (O2BitmapContext)

+ (O2Context *) createWithBytes: (void *) bytes
                          width: (size_t) width
                         height: (size_t) height
               bitsPerComponent: (size_t) bitsPerComponent
                    bytesPerRow: (size_t) bytesPerRow
                     colorSpace: (O2ColorSpaceRef) colorSpace
                     bitmapInfo: (O2BitmapInfo) bitmapInfo
                releaseCallback:
                        (O2BitmapContextReleaseDataCallback) releaseCallback
                    releaseInfo: (void *) releaseInfo
{

    return [[O2Context_builtin_FT alloc] initWithBytes: bytes
                                                 width: width
                                                height: height
                                      bitsPerComponent: bitsPerComponent
                                           bytesPerRow: bytesPerRow
                                            colorSpace: colorSpace
                                            bitmapInfo: bitmapInfo
                                       releaseCallback: releaseCallback
                                           releaseInfo: releaseInfo];
}

@end

@implementation O2Context_builtin_FT

- initWithSurface: (O2Surface *) surface flipped: (BOOL) flipped {
    if ([super initWithSurface: surface flipped: flipped] == nil)
        return nil;

    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (void) establishFontStateInDeviceIfDirty {
    O2GState *gState = O2ContextCurrentGState(self);

    if (gState->_fontIsDirty) {
        O2GStateClearFontIsDirty(gState);
    }
}

static O2Paint *paintFromColor(O2ColorRef color) {
    size_t count = O2ColorGetNumberOfComponents(color);
    const O2Float *components = O2ColorGetComponents(color);

    if (count == 2)
        return [[O2Paint_color alloc] initWithGray: components[0]
                                             alpha: components[1]
                           surfaceToPaintTransform: O2AffineTransformIdentity];
    if (count == 4)
        return [[O2Paint_color alloc] initWithRed: components[0]
                                            green: components[1]
                                             blue: components[2]
                                            alpha: components[3]
                          surfaceToPaintTransform: O2AffineTransformIdentity];

    return [[O2Paint_color alloc] initWithGray: 0
                                         alpha: 1
                       surfaceToPaintTransform: O2AffineTransformIdentity];
}

static void applyCoverageToSpan_lRGBA8888_PRE(O2argb8u *dst,
                                              unsigned char *coverageSpan,
                                              O2argb8u *src, int length)
{
    int i;

    for (i = 0; i < length; i++, src++, dst++) {
        int coverage = coverageSpan[i];
        int oneMinusCoverage = inverseCoverage(coverage);
        O2argb8u r = *src;
        O2argb8u d = *dst;

        *dst = O2argb8uAdd(O2argb8uMultiplyByCoverage(r, coverage),
                           O2argb8uMultiplyByCoverage(d, oneMinusCoverage));
    }
}

static void renderFreeTypeBitmap(O2Context_builtin_FT *self, O2Surface *surface,
                                 FT_Bitmap *bitmap, NSInteger x, NSInteger y,
                                 O2Paint *paint)
{
    // Size of the bitmap.
    NSInteger fullWidth = bitmap->width;
    NSInteger fullHeight = bitmap->rows;

    // What we're going to render, taking clippig into account.
    NSInteger minX = MAX(x, self->_vpx);
    NSInteger maxX = MIN(x + fullWidth, self->_vpx + self->_vpwidth);
    NSInteger minY = MAX(y, self->_vpy);
    NSInteger maxY = MIN(y + fullHeight, self->_vpy + self->_vpheight);

    NSInteger renderWidth = maxX - minX;
    NSInteger renderHeight = maxY - minY;

    if (renderWidth <= 0 || renderHeight <= 0) {
        // Fully clipped.
        return;
    }

    O2argb8u *dstBuffer = __builtin_alloca(renderWidth * sizeof(O2argb8u));
    O2argb8u *srcBuffer = __builtin_alloca(renderWidth * sizeof(O2argb8u));

    for (NSInteger row = 0; row < renderHeight; row++) {
        // Geometry of this row.
        // We're going to change curX & remainingLength as we move along this
        // row.
        NSInteger curX = minX;
        NSInteger curY = minY + row;
        NSInteger remainingLength = renderWidth;

        // We're going to advance these pointers as we move along this row.
        unsigned char *coverage =
                bitmap->buffer + (curY - y) * fullWidth + (curX - x);
        O2argb8u *src = srcBuffer;
        O2argb8u *dst = dstBuffer;

        // Try to get direct access to the surface data.
        O2argb8u *direct = surface->_read_argb8u(surface, curX, curY, dst,
                                                 remainingLength);
        // If that succeeded, write there directly with no temporary buffer.
        if (direct != NULL)
            dst = direct;

        while (remainingLength > 0) {
            // Read next chunk into src.
            int chunk = O2PaintReadSpan_argb8u_PRE(paint, curX, curY, src,
                                                   remainingLength);

            if (chunk < 0) {
                chunk = -chunk;
                // Skip this much pixels.
            } else {
                self->_blend_argb8u_PRE(src, dst, chunk);

                applyCoverageToSpan_lRGBA8888_PRE(dst, coverage, src, chunk);

                if (direct == NULL) {
                    // When direct is NULL, dst is a temporary buffer, not the
                    // surface itself, so we have to write it out to the surface
                    // explicitly.
                    O2SurfaceWriteSpan_argb8u_PRE(surface, curX, curY, dst,
                                                  chunk);
                }
            }

            coverage += chunk;
            remainingLength -= chunk;
            curX += chunk;
            src += chunk;
            dst += chunk;
        }
    }
}

- (void) showGlyphs: (const O2Glyph *) glyphs
           advances: (const O2Size *) advances
              count: (NSUInteger) count
{
    // FIXME: use advances if not NULL

    O2SurfaceLock(_surface);

    O2GState *gState = O2ContextCurrentGState(self);
    O2Paint *paint = paintFromColor(gState->_fillColor);
    O2AffineTransform Trm = O2ContextGetTextRenderingMatrix(self);

    NSPoint point = O2PointApplyAffineTransform(NSMakePoint(0, 0), Trm);

    // Only use the scaling part of the current transform to scale the font size
    O2Float scaleX = sqrt((Trm.a * Trm.a) + (Trm.c * Trm.c));
    O2Float scaleY = sqrt((Trm.b * Trm.b) + (Trm.d * Trm.d));
    O2AffineTransform scalingTransform =
            O2AffineTransformMakeScale(scaleX, scaleY);
    O2Size fontSize = O2SizeApplyAffineTransform(
            O2SizeMake(0, O2GStatePointSize(gState)), scalingTransform);

    [self establishFontStateInDeviceIfDirty];

    O2Font_freetype *font = (O2Font_freetype *) gState->_font;
    FT_Face face = [font face];

    int i;
    FT_Error ftError;

    if (face == NULL) {
        NSLog(@"face is NULL");
        O2SurfaceUnlock(_surface);
        return;
    }

    FT_GlyphSlot slot = face->glyph;

    if ((ftError =
                 FT_Set_Char_Size(face, 0, fontSize.height * 64, 72.0, 72.0))) {
        NSLog(@"FT_Set_Char_Size returned %d", ftError);
        O2SurfaceUnlock(_surface);
        return;
    }

    for (i = 0; i < count; i++) {

        ftError = FT_Load_Glyph(face, glyphs[i], FT_LOAD_DEFAULT);
        if (ftError)
            continue;

        ftError = FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL);
        if (ftError)
            continue;

        renderFreeTypeBitmap(self, _surface, &slot->bitmap,
                             point.x + slot->bitmap_left,
                             point.y - slot->bitmap_top, paint);

        point.x += slot->advance.x >> 6;
    }

    O2PaintRelease(paint);

    int glyphAdvances[count];
    O2Float unitsPerEm = O2FontGetUnitsPerEm(font);

    O2FontGetGlyphAdvances(font, glyphs, count, glyphAdvances);

    O2Float total = 0;

    for (i = 0; i < count; i++)
        total += glyphAdvances[i];

    total = (total / O2FontGetUnitsPerEm(font)) * gState->_pointSize;

    O2SurfaceUnlock(_surface);
}

// Copies the context's surface pixels inside `rect` (user space) into a
// 32bpp BMP so the caller (NSBitmapImageRep -initWithFocusedViewRect:) can
// build an image from them. Mirrors the Windows implementation.
- (NSData *) captureBitmapInRect: (NSRect) rect {
    O2Surface *surface = [self surface];
    size_t surfaceWidth = O2SurfaceGetWidth(surface);
    size_t surfaceHeight = O2SurfaceGetHeight(surface);

    O2AffineTransform transformToDevice =
            O2ContextGetUserSpaceToDeviceSpaceTransform(self);
    NSPoint pt = O2PointApplyAffineTransform(rect.origin, transformToDevice);

    int width = (int) rect.size.width;
    int height = (int) rect.size.height;

    if (width <= 0 || height <= 0)
        return nil;

    if (transformToDevice.d < 0) // flipped (user y up, device y down)
        pt.y -= rect.size.height;

    int startX = (int) pt.x;
    int startY = (int) pt.y;

    // Clamp to the surface
    if (startX < 0) {
        width += startX;
        startX = 0;
    }
    if (startY < 0) {
        height += startY;
        startY = 0;
    }
    if (startX + width > (int) surfaceWidth)
        width = (int) surfaceWidth - startX;
    if (startY + height > (int) surfaceHeight)
        height = (int) surfaceHeight - startY;

    if (width <= 0 || height <= 0)
        return nil;

    static int dbgCount = 0;
    if (dbgCount++ < 4) {
        // histogram of the captured region
        O2argb8u tmp;
        int hits[256] = {0};
        int distinct = 0;
        for (int y = startY; y < startY + height; y++) {
            O2argb8u *row =
                    O2Image_read_argb8u(surface, startX, y, &tmp, 1);
            for (int x = 0; x < width; x++) {
                O2argb8u p = row[x];
                if (p.a == 0) {
                    distinct++;
                    break;
                }
                int key = (p.r >> 4) + (p.g >> 4) + (p.b >> 4);
                hits[key]++;
            }
        }
        fprintf(stderr, "[TRACE] captureBitmap rect=(%.0f,%.0f,%.0f,%.0f) "
                        "pt=(%.0f,%.0f) d=%.2f start=(%d,%d) size=(%dx%d) "
                        "surf=(%zux%zu) opaqueRows=%d\n",
                rect.origin.x, rect.origin.y, rect.size.width,
                rect.size.height, pt.x, pt.y, transformToDevice.d, startX,
                startY, width, height, surfaceWidth, surfaceHeight, distinct);
    }

    unsigned long bmSize = 4 * width * height;
    unsigned char *bmBits = NSZoneMalloc(NULL, bmSize);

    // Rows on the surface go top-down with device y; BMP rows are stored
    // bottom-up, so emit the last memory row first.
    O2argb8u *span = __builtin_alloca(width * sizeof(O2argb8u));
    unsigned long dest = 0;
    for (int row = startY + height - 1; row >= startY; row--) {
        O2argb8u *pixels =
                O2Image_read_argb8u(surface, startX, row, span, width);
        for (int i = 0; i < width; i++) {
            bmBits[dest++] = pixels[i].b;
            bmBits[dest++] = pixels[i].g;
            bmBits[dest++] = pixels[i].r;
            bmBits[dest++] = 255; // force alpha
        }
    }

    // Build a 32bpp BMP (BITMAPFILEHEADER + BITMAPINFOHEADER + pixels).
    // These structs are not available outside Windows, so assemble the header
    // byte by byte (little-endian).
    unsigned char bfHeader[14];
    bfHeader[0] = 'B';
    bfHeader[1] = 'M';
    uint32_t bfOffBits = 14 + 40;
    uint32_t bfSize = bfOffBits + (uint32_t) bmSize;
    memcpy(bfHeader + 2, &bfSize, 4);
    memset(bfHeader + 6, 0, 4); // reserved
    memcpy(bfHeader + 10, &bfOffBits, 4);

    unsigned char biHeader[40];
    memset(biHeader, 0, sizeof(biHeader));
    uint32_t biSize = 40;
    memcpy(biHeader + 0, &biSize, 4);
    int32_t biWidth = width;
    int32_t biHeight = height;
    memcpy(biHeader + 4, &biWidth, 4);
    memcpy(biHeader + 8, &biHeight, 4);
    uint16_t biPlanes = 1;
    uint16_t biBitCount = 32;
    uint32_t biCompression = 0; // BI_RGB
    memcpy(biHeader + 12, &biPlanes, 2);
    memcpy(biHeader + 14, &biBitCount, 2);
    memcpy(biHeader + 16, &biCompression, 4);
    memcpy(biHeader + 20, &bmSize, 4); // biSizeImage

    NSMutableData *result =
            [NSMutableData dataWithBytes: bfHeader length: sizeof(bfHeader)];
    [result appendBytes: biHeader length: sizeof(biHeader)];
    [result appendBytes: bmBits length: bmSize];

    NSZoneFree(NULL, bmBits);

    return result;
}

@end
