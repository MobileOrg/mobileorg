//
//  GlobalUtils.m
//  MobileOrg
//
//  Created by Richard Moreland on 9/30/09.
//  Copyright 2009 Richard Moreland.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

#import "GlobalUtils.h"
#import "Settings.h"
#import "MobileOrgAppDelegate.h"
#import "OutlineViewController.h"
#import "CommonCrypto/CommonCryptor.h"
#import "CommonCrypto/CommonDigest.h"

MobileOrgAppDelegate *AppInstance() {
    return (MobileOrgAppDelegate*)[[UIApplication sharedApplication] delegate];
}

NSString *UUID() {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    NSString *uuidString = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return [uuidString autorelease];
}

NSString *FileWithName(NSString *name) {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:name];
}

NSString *TemporaryFilename() {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:UUID()];
}

void DeleteFile(NSString *filename) {
    NSFileManager *NSFm = [NSFileManager defaultManager];
    if ([NSFm fileExistsAtPath:filename]) {
        NSError *e;
        [NSFm removeItemAtPath:filename error:&e];
    }
}

void UpdateEditActionCount() {
    [[AppInstance() rootOutlineController] updateBadge];
}

// Get rid of any '*' characters in column zero by padding them with space in column 0.
// This changes what the user entered, but they shouldn't have done it in the first place.
NSString *EscapeHeadings(NSString *original) {
    NSString *ret = [NSString stringWithString:original];
    if ([original length] > 0) {
        if ([original characterAtIndex:0] == '*') {
            ret = [NSString stringWithFormat:@" %@", original];
        }
    }
    ret = [ret stringByReplacingOccurrencesOfString:@"\n*" withString:@"\n *"];
    return ret;
}

void UpdateAppBadge() {
    int count = 0;
    if ([[Settings instance] appBadgeMode] == AppBadgeModeTotal) {

        count += [[[AppInstance() noteListController] navigationController].tabBarItem.badgeValue intValue];
        count += [[[AppInstance() rootOutlineController] navigationController].tabBarItem.badgeValue intValue];

        // are you running on >= iOS8?
        // Not necessary because we're starting with 8
        // But safe is safe 🦄
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge|UIUserNotificationTypeAlert|UIUserNotificationTypeSound) categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        }
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:count];
    }
    else {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
}

// http://stackoverflow.com/questions/2576356/how-does-one-get-ui-user-interface-idiom-to-work-with-iphone-os-sdk-3-2
BOOL IsIpad() {
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 30200)
    if ([[UIDevice currentDevice] respondsToSelector: @selector(userInterfaceIdiom)])
        return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
#endif
    return NO;
}

NSString *ReadPossiblyEncryptedFile(NSString *filename, NSString **error) {
    *error = nil;
    
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:filename];
    if (!data) {
        *error = @"Unable to open file";
        return nil;
    }
    
    char buffer[16];
    [data getBytes:buffer length:8];        
    if (!strncmp((const char*)buffer, "Salted__", 8)) {
        NSData *decryptedData = [data AES256DecryptWithKey:[[Settings instance] encryptionPassword]];
        if (decryptedData) {
            if ([decryptedData length] > 0) {
                NSString *tmpFileName = FileWithName(@"decrypted-file.org");
                [[NSFileManager defaultManager] createFileAtPath:tmpFileName contents:decryptedData attributes:nil];              

                NSStringEncoding encoding;
                NSError *e;
                NSString *ret = [NSString stringWithContentsOfFile:tmpFileName usedEncoding:&encoding error:&e];

                DeleteFile(FileWithName(@"decrypted-file.org"));
                
               return ret;
            } else {
                return @"";
            }
        } else {
            *error = @"Unable to decrypt file";
            return nil;
        }      
    } else {
        NSStringEncoding encoding;
        NSError *e;
        return [NSString stringWithContentsOfFile:filename usedEncoding:&encoding error:&e];
    }
}

// From: http://stackoverflow.com/questions/652300/using-md5-hash-on-a-string-in-cocoa
NSString *md5(unsigned char *bytes, size_t len) {
    unsigned char result[16];
    CC_MD5( bytes, (unsigned int)len, result );
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3], 
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ]; 
}

static const int SaltPrefixLen = 8;
static const int SaltLen = 8;

void ExtractKeyAndIVFromPassphrase(const char *pass,
                                   const unsigned char *salt, 
                                   unsigned char *key, unsigned char *iv)
{
    // http://deusty.blogspot.com/2009/04/decrypting-openssl-aes-files-in-c.html
    // Link above was very helpful in determing how this should work.

    //NSLog(@"salt: %@", [NSString stringWithFormat:
    //                    @"%02X%02X%02X%02X%02X%02X%02X%02X",
    //                    salt[0], salt[1], salt[2], salt[3], 
    //                    salt[4], salt[5], salt[6], salt[7]
    //                    ]); 
    
    size_t passLen = strlen(pass);
    unsigned char lastKey[kCCKeySizeAES128];    
    unsigned char tmpStr[kCCKeySizeAES128 + passLen + SaltLen];

    memcpy(tmpStr, pass, passLen);
    memcpy(tmpStr + passLen, &salt[0], SaltLen);
    CC_MD5(tmpStr, (unsigned int)passLen + SaltLen, lastKey);
    memcpy(key, lastKey, kCCKeySizeAES128);   
    //NSLog(@"key1: %@", md5(tmpStr, passLen + SaltLen));
          
    memcpy(tmpStr, key, kCCKeySizeAES128);
    memcpy(tmpStr + kCCKeySizeAES128, pass, passLen);
    memcpy(tmpStr + kCCKeySizeAES128 + passLen, &salt[0], SaltLen);
    CC_MD5(tmpStr, kCCKeySizeAES128 + (unsigned int)passLen + SaltLen, lastKey);
    memcpy(key + kCCKeySizeAES128, lastKey, kCCKeySizeAES128);   
    //NSLog(@"key2: %@", md5(tmpStr, kCCKeySizeAES128 + passLen + SaltLen));
    
    memcpy(tmpStr, lastKey, kCCKeySizeAES128);
    memcpy(tmpStr + kCCKeySizeAES128, pass, passLen);
    memcpy(tmpStr + kCCKeySizeAES128 + passLen, &salt[0], SaltLen);
    CC_MD5(tmpStr, kCCKeySizeAES128 + (unsigned int)passLen + SaltLen, iv);
    //NSLog(@"iv: %@", md5(tmpStr, kCCKeySizeAES128 + passLen + SaltLen));
}

// From: http://pastie.org/426530
@implementation NSData (AES256)

- (NSData *)AES256EncryptWithKey:(NSString *)passphrase {
    
    unsigned char key[kCCKeySizeAES256];
    unsigned char iv[kCCKeySizeAES128];
    unsigned char salt[SaltLen];
    const unsigned char *bytes = [self bytes];
    void *buffer;
    
    size_t bytesLen = [self length];
    size_t bufferSize = bytesLen + kCCBlockSizeAES128 + SaltPrefixLen + SaltLen;
    
    // Generate the salt, prepend it to the buffer
    time_t now = time(NULL);
    memcpy(salt, &now, sizeof(time_t));
    
    buffer = malloc(bufferSize);
    bzero(buffer, bufferSize);
    strcpy(buffer, "Salted__");
    memcpy(buffer+SaltPrefixLen, salt, SaltLen);

    ExtractKeyAndIVFromPassphrase([passphrase cStringUsingEncoding:NSASCIIStringEncoding], salt, key, iv);    
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          key, kCCKeySizeAES256,
                                          iv,
                                          bytes, bytesLen,
                                          buffer+SaltPrefixLen+SaltLen, bufferSize-SaltPrefixLen-SaltLen,
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess) {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:(numBytesEncrypted+SaltPrefixLen+SaltLen)];
    }
    else {
        // TODO: Unknown error
    }
    
    free(buffer);
    return nil;
}

- (NSData *)AES256DecryptWithKey:(NSString *)passphrase {

    unsigned char key[kCCKeySizeAES256];
    unsigned char iv[kCCKeySizeAES128];
    unsigned char salt[SaltLen];
    const unsigned char *bytes = [self bytes];
    void *buffer;

    size_t bytesLen = [self length];
    size_t bufferSize = bytesLen + kCCBlockSizeAES128 + 1;

    // Extract the salt, advance the byte buffer
    memcpy(salt, [self bytes] + SaltPrefixLen, SaltLen);
    bytesLen -= (SaltPrefixLen + SaltLen);
    bytes += (SaltPrefixLen + SaltLen);

    ExtractKeyAndIVFromPassphrase([passphrase cStringUsingEncoding:NSASCIIStringEncoding], salt, key, iv);    

    buffer = malloc(bufferSize);
    bzero(buffer, bufferSize);

    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          key, kCCKeySizeAES256,
                                          iv,
                                          bytes, bytesLen,
                                          buffer, bufferSize,
                                          &numBytesDecrypted);

    // Add a null character at the end to terminate the string
    // FUTURE TODO: This obviously isn't a good idea if we're handling anything other than text!
    ((char*)buffer)[numBytesDecrypted++] = '\0';
    
    if (cryptStatus == kCCSuccess) {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    else if (cryptStatus == kCCDecodeError) {
        // TODO: Error, likely a bad password
    }
    else {
        // TODO: Unknown error
    }

    free(buffer);
    return nil;
}

@end
