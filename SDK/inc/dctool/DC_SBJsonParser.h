/*
 Copyright (C) 2009 Stig Brautaset. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
 
 * Neither the name of the author nor the names of its contributors may be used
   to endorse or promote products derived from this software without specific
   prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "DC_SBJsonBase.h"

/**
  @brief Options for the parser class.
 
 This exists so the DC_ facade can implement the options in the parser without having to re-declare them.
 */
@protocol DC_SBJsonParser

/**
 @brief Return the object represented by the given string.
 
 Returns the object represented by the passed-in string or nil on error. The returned object can be
 a string, number, boolean, null, array or dictionary.
 
 @param repr the json string to parse
 */
- (id)objectWithString:(NSString *)repr;

@end


/**
 @brief The JSON parser class.
 
 JSON is mapped to Objective-C types in the following way:
 
 @li Null -> NSNull
 @li String -> NSMutableString
 @li Array -> NSMutableArray
 @li Object -> NSMutableDictionary
 @li Boolean -> NSNumber (initialised with -initWithBool:)
 @li Number -> NSDecimalNumber
 
 Since Objective-C doesn't have a dedicated class for boolean values, these turns into NSNumber
 instances. These are initialised with the -initWithBool: method, and 
 round-trip back to JSON properly. (They won't silently suddenly become 0 or 1; they'll be
 represented as 'true' and 'false' again.)
 
 JSON numbers turn into NSDecimalNumber instances,
 as we can thus avoid any loss of precision. (JSON allows ridiculously large numbers.)
 
 */
@interface DC_SBJsonParser : DC_SBJsonBase <DC_SBJsonParser> {
    
@private
    const char *c;
}

@end

// don't use - exists for backwards compatibility with 2.1.x only. Will be removed in 2.3.
@interface DC_SBJsonParser (Private)
- (id)fragmentWithString:(id)repr;
@end


