/*
 * MultitouchSupport.h
 *
 * C header for MultitouchSupport private framework
 * Provides access to raw multitouch data from Magic Mouse and trackpads
 */

#ifndef MultitouchSupport_h
#define MultitouchSupport_h

#include <stdint.h>
#include <stdbool.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

typedef uint32_t MTTouchState;

enum {
    MTTouchStateNotTracking = 0,
    MTTouchStateStartInRange = 1,
    MTTouchStateHoverInRange = 2,
    MTTouchStateMakeTouch = 3,
    MTTouchStateTouching = 4,
    MTTouchStateBreakTouch = 5,
    MTTouchStateLingerInRange = 6,
    MTTouchStateOutOfRange = 7
};

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t pathIndex;
    MTTouchState state;
    int32_t fingerID;
    int32_t handID;
    MTVector normalizedVector;
    float zTotal;
    int32_t field9;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absoluteVector;
    int32_t field14;
    int32_t field15;
    float zDensity;
} MTTouch;

typedef const void* MTDeviceRef;

typedef void (*MTFrameCallbackFunction)(MTDeviceRef device,
                                       MTTouch* touches,
                                       size_t numTouches,
                                       double timestamp,
                                       size_t frame);

typedef void (*MTFrameCallbackRefconFunction)(MTDeviceRef device,
                                             MTTouch* touches,
                                             size_t numTouches,
                                             double timestamp,
                                             size_t frame,
                                             void* refcon);

CFArrayRef MTDeviceCreateList(void);
MTDeviceRef MTDeviceCreateDefault(void);
void MTDeviceRelease(MTDeviceRef);
bool MTDeviceIsRunning(MTDeviceRef);
bool MTDeviceIsValid(MTDeviceRef);

OSStatus MTDeviceGetFamilyID(MTDeviceRef, int*);
OSStatus MTDeviceGetDriverType(MTDeviceRef, int*);

void MTRegisterContactFrameCallback(MTDeviceRef, MTFrameCallbackFunction);
void MTRegisterContactFrameCallbackWithRefcon(MTDeviceRef, MTFrameCallbackRefconFunction, void* refcon);
void MTUnregisterContactFrameCallback(MTDeviceRef, MTFrameCallbackRefconFunction);

OSStatus MTDeviceStart(MTDeviceRef, int);
OSStatus MTDeviceStop(MTDeviceRef);

#endif /* MultitouchSupport_h */
