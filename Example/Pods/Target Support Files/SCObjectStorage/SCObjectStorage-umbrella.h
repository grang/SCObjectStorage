#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "ObjectStorage.h"

FOUNDATION_EXPORT double SCObjectStorageVersionNumber;
FOUNDATION_EXPORT const unsigned char SCObjectStorageVersionString[];

