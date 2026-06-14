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
#import "CMMachineSelectionCell.h"

static BOOL CMIsDarkAppearance(NSView *view)
{
    NSString *match = [[view effectiveAppearance] bestMatchFromAppearancesWithNames:@[
        NSAppearanceNameAqua,
        NSAppearanceNameDarkAqua,
    ]];
    return [match isEqualToString:NSAppearanceNameDarkAqua];
}

@implementation CMMachineSelectionCell

- (BOOL)isRowHighlightedInView:(NSView *)controlView frame:(NSRect)cellFrame
{
    if (![controlView isKindOfClass:[NSTableView class]])
        return NO;

    NSTableView *tableView = (NSTableView *)controlView;
    NSInteger cellRow = [tableView rowAtPoint:cellFrame.origin];
    return [tableView isRowSelected:cellRow];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [[controlView effectiveAppearance] performAsCurrentDrawingAppearance:^{
        [super drawInteriorWithFrame:cellFrame inView:controlView];
    }];

    if ([self downloadingIconVisible])
    {
        BOOL isHighlighted = [self isRowHighlightedInView:controlView frame:cellFrame];
        NSImage *downloadIcon;

        if (isHighlighted || CMIsDarkAppearance(controlView))
            downloadIcon = [NSImage imageNamed:@"icon-downloading-inverse"];
        else
            downloadIcon = [NSImage imageNamed:@"icon-downloading"];

        [[controlView effectiveAppearance] performAsCurrentDrawingAppearance:^{
            [controlView lockFocus];

            [downloadIcon drawInRect:NSMakeRect(cellFrame.origin.x + (cellFrame.size.width - downloadIcon.size.width) / 2.0,
                                                cellFrame.origin.y + (cellFrame.size.height - downloadIcon.size.height) / 2.0,
                                                downloadIcon.size.width,
                                                downloadIcon.size.height)
                            fromRect:NSMakeRect(0, 0, downloadIcon.size.width, downloadIcon.size.height)
                           operation:NSCompositeSourceOver
                            fraction:1.0
                      respectFlipped:YES
                               hints:nil];

            [controlView unlockFocus];
        }];
    }
}

@end
