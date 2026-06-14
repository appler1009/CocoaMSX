/*****************************************************************************
 **
 ** CocoaMSX: MSX Emulator for Mac OS X
 ** http://www.cocoamsx.com
 ** Copyright (C) 2012-2016 Akop Karapetyan
 **
 ** This program is free software; you can redistribute it and/or modify
 ** it under the terms of the GNU General Public License as published by
 ** the Free Software Foundation; either version 2 of the License, or
 ** (at your option) any later version.
 **
 ** This program is distributed in the hope that it will be useful,
 ** but WITHOUT ANY WARRANTY; without even the implied warranty of
 ** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ** GNU General Public License for more details.
 **
 ** You should have received a copy of the GNU General Public License
 ** along with this program; if not, write to the Free Software
 ** Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 **
 ******************************************************************************
 */
#import "CMMacKeyboardLayout.h"

#import <AppKit/NSEvent.h>
#import <Carbon/Carbon.h>

NSString * const CMMacKeyboardLayoutPrefKey = @"macKeyboardLayout";

NSString * const CMMacKeyboardLayoutUSIdentifier = @"us";
NSString * const CMMacKeyboardLayoutCanadianIdentifier = @"canadian";

static NSDictionary<NSString *, NSString *> *layoutInputSourceIDs;
static NSDictionary<NSString *, NSString *> *layoutLabels;

@implementation CMMacKeyboardLayout

+ (void)initialize
{
    layoutInputSourceIDs = @{
        CMMacKeyboardLayoutUSIdentifier: @"com.apple.keylayout.ABC",
        CMMacKeyboardLayoutCanadianIdentifier: @"com.apple.keylayout.Canadian",
    };

    layoutLabels = @{
        CMMacKeyboardLayoutUSIdentifier: @"U.S.",
        CMMacKeyboardLayoutCanadianIdentifier: @"Canadian",
    };
}

+ (NSArray<NSString *> *)availableLayoutIdentifiers
{
    return @[CMMacKeyboardLayoutUSIdentifier, CMMacKeyboardLayoutCanadianIdentifier];
}

+ (NSString *)labelForLayoutIdentifier:(NSString *)identifier
{
    return layoutLabels[identifier] ?: identifier;
}

+ (NSString *)effectiveLayoutIdentifier
{
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:CMMacKeyboardLayoutPrefKey];
    if ([[self availableLayoutIdentifiers] containsObject:stored])
        return stored;

    TISInputSourceRef currentSource = TISCopyCurrentKeyboardInputSource();
    if (currentSource)
    {
        CFStringRef sourceID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID);
        if (sourceID && CFStringCompare(sourceID, CFSTR("com.apple.keylayout.Canadian"), 0) == kCFCompareEqualTo)
        {
            CFRelease(currentSource);
            return CMMacKeyboardLayoutCanadianIdentifier;
        }
        CFRelease(currentSource);
    }

    return CMMacKeyboardLayoutUSIdentifier;
}

+ (NSString *)inputSourceIDForLayoutIdentifier:(NSString *)identifier
{
    return layoutInputSourceIDs[identifier] ?: layoutInputSourceIDs[CMMacKeyboardLayoutUSIdentifier];
}

+ (TISInputSourceRef)copyInputSourceForLayoutIdentifier:(NSString *)identifier
{
    NSString *sourceID = [self inputSourceIDForLayoutIdentifier:identifier];
    CFArrayRef sources = TISCreateInputSourceList(NULL, false);
    TISInputSourceRef match = NULL;

    if (sources)
    {
        for (CFIndex i = 0; i < CFArrayGetCount(sources); i++)
        {
            TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, i);
            CFStringRef candidateID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID);
            if (candidateID && [(__bridge NSString *)candidateID isEqualToString:sourceID])
            {
                match = source;
                CFRetain(match);
                break;
            }
        }
        CFRelease(sources);
    }

    return match;
}

+ (NSString *)characterForKeyCode:(NSUInteger)keyCode
                        modifiers:(NSUInteger)modifierFlags
               layoutIdentifier:(NSString *)layoutIdentifier
{
    TISInputSourceRef source = [self copyInputSourceForLayoutIdentifier:layoutIdentifier];
    if (!source)
        return nil;

    NSString *character = nil;
    CFDataRef layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData);
    if (layoutData)
    {
        const UCKeyboardLayout *keyLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
        UInt32 macModifiers = 0;
        if (modifierFlags & NSEventModifierFlagShift)
            macModifiers |= shiftKey;
        if (modifierFlags & NSEventModifierFlagControl)
            macModifiers |= controlKey;
        if (modifierFlags & NSEventModifierFlagOption)
            macModifiers |= optionKey;
        if (modifierFlags & NSEventModifierFlagCapsLock)
            macModifiers |= alphaLock;

        UniChar chars[4];
        UniCharCount length = 4;
        UniCharCount actualLength = 0;
        UInt32 deadKeyState = 0;

        OSStatus err = UCKeyTranslate(keyLayout,
                                      (UInt16)keyCode,
                                      kUCKeyActionDisplay,
                                      macModifiers,
                                      LMGetKbdType(),
                                      kUCKeyTranslateNoDeadKeysBit,
                                      &deadKeyState,
                                      length,
                                      &actualLength,
                                      chars);
        if (err == noErr && actualLength > 0)
            character = [[NSString alloc] initWithCharacters:chars length:actualLength];
    }

    CFRelease(source);
    return character;
}

+ (NSString *)displayLabelForKeyCode:(NSUInteger)keyCode
                           modifiers:(NSUInteger)modifierFlags
                  layoutIdentifier:(NSString *)layoutIdentifier
{
    NSString *character = [self characterForKeyCode:keyCode
                                         modifiers:modifierFlags
                                layoutIdentifier:layoutIdentifier];
    if (!character || character.length == 0)
        return nil;

    if (character.length == 1)
    {
        unichar c = [character characterAtIndex:0];
        if (c == '\r' || c == '\n')
            return @"Return";
        if (c == '\t')
            return @"Tab";
        if (c == ' ')
            return @"Space";
    }

    return character;
}

+ (BOOL)isCharacterMappingPreferredForKeyCode:(NSUInteger)keyCode
{
    switch (keyCode)
    {
        case 54: // Right Command
        case 55: // Left Command
        case 56: // Left Shift
        case 57: // Caps Lock
        case 58: // Left Option
        case 59: // Left Control
        case 60: // Right Shift
        case 61: // Right Option
        case 62: // Right Control
        case 63: // Function
            return NO;

        case 0x7A: // F1
        case 0x78: // F2
        case 0x63: // F3
        case 0x76: // F4
        case 0x60: // F5
        case 0x61: // F6
        case 0x62: // F7
        case 0x64: // F8
        case 0x65: // F9
        case 0x6D: // F10
        case 0x67: // F11
        case 0x6F: // F12
            return NO;

        case 0x7B: // Left
        case 0x7C: // Right
        case 0x7D: // Down
        case 0x7E: // Up
        case 0x73: // Home
        case 0x77: // End
        case 0x74: // Page Up
        case 0x79: // Page Down
        case 0x72: // Insert / Help
        case 0x75: // Forward Delete
            return NO;
    }

    return YES;
}

@end
