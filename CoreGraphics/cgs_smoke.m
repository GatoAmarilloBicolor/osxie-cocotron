#include <CoreGraphics/CoreGraphicsPrivate.h>
#include <CoreGraphics/CGSConnection.h>
#include <CoreGraphics/CGSWindow.h>
#include <CoreGraphics/CGSSurface.h>
#include <CoreGraphics/CGSScreen.h>
#include <X11/Xlib.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static CGSWindowID g_wid = 0;

static void checkMapped(Display* dpy, Window win)
{
	for (int i = 0; i < 50; i++)
	{
		XWindowAttributes attrs;
		if (XGetWindowAttributes(dpy, win, &attrs) && attrs.map_state == IsViewable)
		{
			printf("window mapped: %dx%d @ %d,%d\n", attrs.width, attrs.height,
				attrs.x, attrs.y);
			return;
		}
		usleep(100000);
	}
	printf("WARN: window never became viewable\n");
}

int main(void)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	const char* disp = getenv("DISPLAY");
	printf("DISPLAY=%s\n", disp ? disp : "(null)");

	NSBundle* cgBundle = [NSBundle bundleForClass: [CGSConnection class]];
	printf("cgBundle bundlePath=%s\n", cgBundle ? [[cgBundle bundlePath] UTF8String] : "(null)");
	if (cgBundle)
		printf("cgBundle resourcePath=%s\n", [[cgBundle resourcePath] UTF8String]);

	NSArray* paths = [cgBundle pathsForResourcesOfType: @"backend" inDirectory: @"Backends"];
	printf("backend paths=%ld\n", paths ? (long) [paths count] : -1L);
	for (NSString* p in paths)
		printf("  backend: %s\n", [p UTF8String]);

	const char* candidates[] = {
		"/System/Library/Frameworks/CoreGraphics.framework/Backends",
		"/System/Library/Frameworks/CoreGraphics.framework/Resources/Backends",
		"/System/Library/Frameworks/CoreGraphics.framework/Versions/A/Resources/Backends",
		NULL
	};
	for (int i = 0; candidates[i]; i++)
	{
		struct stat st;
		if (stat(candidates[i], &st) == 0)
		{
			NSArray* entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:
				[NSString stringWithUTF8String: candidates[i]] error: nil];
			printf("stat OK %s -> %ld entries\n", candidates[i], entries ? (long) [entries count] : -1L);
		}
		else
			printf("stat FAIL %s\n", candidates[i]);
	}

	CGSConnectionID conn;
	CGError err = CGSNewConnection(NULL, &conn);
	if (err != kCGSErrorSuccess)
	{
		printf("FAIL: CGSNewConnection err=%d\n", err);
		return 1;
	}
	printf("connection id=%d\n", conn);

	Display* dpy = (Display*) _CGSNativeDisplay(conn);
	if (!dpy)
	{
		printf("FAIL: no native display\n");
		return 1;
	}
	printf("native display=%p\n", dpy);

	CGSConnection* connObj = _CGSConnectionForID(conn);
	if (!connObj)
	{
		printf("FAIL: no connection object\n");
		return 1;
	}
	CGPoint mouse = [connObj mouseLocation];
	printf("mouse location=%.0f,%.0f\n", mouse.x, mouse.y);

	CGRect rect = CGRectMake(100, 100, 320, 200);
	CGSRegionRef region;
	CGSNewRegionWithRect(&rect, &region);

	err = CGSNewWindow(conn, 0, 0, 0, region, &g_wid);
	if (err != kCGSErrorSuccess)
	{
		printf("FAIL: CGSNewWindow err=%d\n", err);
		return 1;
	}
	printf("window id=%d\n", g_wid);

	Window win = (Window) _CGSNativeWindowForID(conn, g_wid);
	if (!win)
	{
		printf("FAIL: no native window\n");
		return 1;
	}
	printf("native window=0x%lx\n", (unsigned long) win);

	err = CGSSetWindowTitle(conn, g_wid, CFSTR("CGS Smoke Window"));
	printf("set title err=%d\n", err);

	CFTypeRef titleOut = NULL;
	err = CGSGetWindowProperty(conn, g_wid, kCGSWindowTitle, &titleOut);
	printf("get title err=%d title=%s\n", err,
		titleOut ? [(NSString*) titleOut UTF8String] : "(null)");
	if (titleOut)
		CFRelease(titleOut);

	OSStatus st = CGSOrderWindow(conn, g_wid, kCGSOrderIn, 0);
	printf("order in=%d\n", (int) st);

	CGPoint pt = CGPointMake(150, 150);
	err = CGSMoveWindow(conn, g_wid, &pt);
	printf("moveTo err=%d\n", err);

	CGSSurfaceID sid;
	err = CGSAddSurface(conn, g_wid, &sid);
	printf("add surface err=%d sid=%d\n", err, sid);

	if (err == kCGSErrorSuccess)
	{
		err = CGSSetSurfaceBounds(conn, g_wid, sid, CGRectMake(10, 10, 300, 180));
		printf("set surface bounds err=%d\n", err);

		void* nativeSurface = _CGSNativeWindowForSurfaceID(conn, g_wid, sid);
		printf("native surface=0x%lx\n", nativeSurface ? (unsigned long) (Window) nativeSurface : 0UL);
	}

	NSArray* screens = [connObj createScreens];
	printf("screens=%ld\n", screens ? (long) [screens count] : -1L);
	if (screens && [screens count] > 0)
	{
		CGSScreen* scr = [screens objectAtIndex: 0];
		printf("screen[0] modes=%ld currentMode=%ld height=%u\n",
			scr.modes ? (long) [scr.modes count] : -1L,
			(long) scr.currentMode,
			[scr currentModeHeight]);
	}
	[screens release];

	CGRect got;
	CGSWindow* wobj = [connObj windowForId: g_wid];
	err = [wobj getRect: &got];
	printf("getRect err=%d rect=%.0f,%.0f %.0fx%.0f\n", err, got.origin.x, got.origin.y, got.size.width, got.size.height);

	checkMapped(dpy, win);

	printf("sleeping 3s so you can see the window...\n");
	fflush(stdout);
	sleep(3);

	err = CGSReleaseWindow(conn, g_wid);
	printf("release window err=%d\n", err);

	err = CGSReleaseConnection(conn);
	printf("release connection err=%d\n", err);

	printf("CGS_SMOKE_OK\n");
	return 0;
}
