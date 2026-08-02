/*
 This file is part of Osxie.

 Copyright (C) 2019 Lubos Dolezel

 Osxie is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Osxie is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Osxie.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <QuartzCore/CALayer.h>

CA_EXPORT NSString *const kCAFillRuleNonZero;
CA_EXPORT NSString *const kCAFillRuleEvenOdd;
CA_EXPORT NSString *const kCALineJoinMiter;
CA_EXPORT NSString *const kCALineJoinRound;
CA_EXPORT NSString *const kCALineJoinBevel;
CA_EXPORT NSString *const kCALineCapButt;
CA_EXPORT NSString *const kCALineCapRound;
CA_EXPORT NSString *const kCALineCapSquare;

@interface CAShapeLayer : CALayer
@end
