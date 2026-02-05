/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVFile.h"
#import "CDVAssetLibraryFilesystem.h"
#import <Cordova/CDV.h>
// MIGRATED TO PHOTOS FRAMEWORK FOR iOS 26 COMPATIBILITY
// AssetsLibrary was deprecated in iOS 9 and removed in iOS 26
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

NSString* const kCDVAssetsLibraryPrefix = @"assets-library://";
NSString* const kCDVAssetsLibraryScheme = @"assets-library";

@implementation CDVAssetLibraryFilesystem
@synthesize name=_name, urlTransformer;


/*
 The CDVAssetLibraryFilesystem works with resources which are identified
 by iOS as
   asset-library://<path>
 and represents them internally as URLs of the form
   cdvfile://localhost/assets-library/<path>
 */

- (NSURL *)assetLibraryURLForLocalURL:(CDVFilesystemURL *)url
{
    if ([url.url.scheme isEqualToString:kCDVFilesystemURLPrefix]) {
        NSString *path = [[url.url absoluteString] substringFromIndex:[@"cdvfile://localhost/assets-library" length]];
        return [NSURL URLWithString:[NSString stringWithFormat:@"assets-library:/%@", path]];
    }
    return url.url;
}

- (CDVPluginResult *)entryForLocalURI:(CDVFilesystemURL *)url
{
    NSDictionary* entry = [self makeEntryForLocalURL:url];
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:entry];
}

- (NSDictionary *)makeEntryForLocalURL:(CDVFilesystemURL *)url {
    return [self makeEntryForPath:url.fullPath isDirectory:NO];
}

- (NSDictionary*)makeEntryForPath:(NSString*)fullPath isDirectory:(BOOL)isDir
{
    NSMutableDictionary* dirEntry = [NSMutableDictionary dictionaryWithCapacity:5];
    NSString* lastPart = [fullPath lastPathComponent];
    if (isDir && ![fullPath hasSuffix:@"/"]) {
        fullPath = [fullPath stringByAppendingString:@"/"];
    }
    [dirEntry setObject:[NSNumber numberWithBool:!isDir]  forKey:@"isFile"];
    [dirEntry setObject:[NSNumber numberWithBool:isDir]  forKey:@"isDirectory"];
    [dirEntry setObject:fullPath forKey:@"fullPath"];
    [dirEntry setObject:lastPart forKey:@"name"];
    [dirEntry setObject:self.name forKey: @"filesystemName"];

    NSURL* nativeURL = [NSURL URLWithString:[NSString stringWithFormat:@"assets-library:/%@",fullPath]];
    if (self.urlTransformer) {
        nativeURL = self.urlTransformer(nativeURL);
    }
    dirEntry[@"nativeURL"] = [nativeURL absoluteString];

    return dirEntry;
}

/* helper function to get the mimeType from the file extension
 * IN:
 *	NSString* fullPath - filename (may include path)
 * OUT:
 *	NSString* the mime type as type/subtype.  nil if not able to determine
 */
+ (NSString*)getMimeTypeFromPath:(NSString*)fullPath
{
    NSString* mimeType = nil;

    if (fullPath) {
        CFStringRef typeId = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fullPath pathExtension], NULL);
        if (typeId) {
            mimeType = (__bridge_transfer NSString*)UTTypeCopyPreferredTagWithClass(typeId, kUTTagClassMIMEType);
            if (!mimeType) {
                // special case for m4a
                if ([(__bridge NSString*)typeId rangeOfString : @"m4a-audio"].location != NSNotFound) {
                    mimeType = @"audio/mp4";
                } else if ([[fullPath pathExtension] rangeOfString:@"wav"].location != NSNotFound) {
                    mimeType = @"audio/wav";
                } else if ([[fullPath pathExtension] rangeOfString:@"css"].location != NSNotFound) {
                    mimeType = @"text/css";
                }
            }
            CFRelease(typeId);
        }
    }
    return mimeType;
}

- (id)initWithName:(NSString *)name
{
    if (self) {
        self.name = name;
    }
    return self;
}

- (CDVPluginResult *)getFileForURL:(CDVFilesystemURL *)baseURI requestedPath:(NSString *)requestedPath options:(NSDictionary *)options
{
    // return unsupported result for assets-library URLs
   return [CDVPluginResult resultWithStatus:CDVCommandStatus_MALFORMED_URL_EXCEPTION messageAsString:@"getFile not supported for assets-library URLs."];
}

- (CDVPluginResult*)getParentForURL:(CDVFilesystemURL *)localURI
{
    // we don't (yet?) support getting the parent of an asset
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsInt:NOT_READABLE_ERR];
}

- (CDVPluginResult*)setMetadataForURL:(CDVFilesystemURL *)localURI withObject:(NSDictionary *)options
{
    // setMetadata doesn't make sense for asset library files
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
}

- (CDVPluginResult *)removeFileAtURL:(CDVFilesystemURL *)localURI
{
    // return error for assets-library URLs
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsInt:INVALID_MODIFICATION_ERR];
}

- (CDVPluginResult *)recursiveRemoveFileAtURL:(CDVFilesystemURL *)localURI
{
    // return error for assets-library URLs
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_MALFORMED_URL_EXCEPTION messageAsString:@"removeRecursively not supported for assets-library URLs."];
}

- (CDVPluginResult *)readEntriesAtURL:(CDVFilesystemURL *)localURI
{
    // return unsupported result for assets-library URLs
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_MALFORMED_URL_EXCEPTION messageAsString:@"readEntries not supported for assets-library URLs."];
}

- (CDVPluginResult *)truncateFileAtURL:(CDVFilesystemURL *)localURI atPosition:(unsigned long long)pos
{
    // assets-library files can't be truncated
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsInt:NO_MODIFICATION_ALLOWED_ERR];
}

- (CDVPluginResult *)writeToFileAtURL:(CDVFilesystemURL *)localURL withData:(NSData*)encData append:(BOOL)shouldAppend
{
    // text can't be written into assets-library files
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsInt:NO_MODIFICATION_ALLOWED_ERR];
}

- (void)copyFileToURL:(CDVFilesystemURL *)destURL withName:(NSString *)newName fromFileSystem:(NSObject<CDVFileSystem> *)srcFs atURL:(CDVFilesystemURL *)srcURL copy:(BOOL)bCopy callback:(void (^)(CDVPluginResult *))callback
{
    // Copying to an assets library file is not doable, since we can't write it.
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsInt:INVALID_MODIFICATION_ERR];
    callback(result);
}

- (NSString *)filesystemPathForURL:(CDVFilesystemURL *)url
{
    NSString *path = nil;
    if ([[url.url scheme] isEqualToString:kCDVAssetsLibraryScheme]) {
        path = [url.url path];
    } else {
       path = url.fullPath;
    }
    if ([path hasSuffix:@"/"]) {
      path = [path substringToIndex:([path length]-1)];
    }
    return path;
}

- (void)readFileAtURL:(CDVFilesystemURL *)localURL start:(NSInteger)start end:(NSInteger)end callback:(void (^)(NSData*, NSString* mimeType, CDVFileError))callback
{
    // MIGRATED TO PHOTOS FRAMEWORK FOR iOS 26
    // Convert assets-library:// URL to PHAsset localIdentifier
    NSURL *assetURL = [self assetLibraryURLForLocalURL:localURL];
    NSString *urlString = [assetURL absoluteString];

    // Extract the asset identifier from the URL
    // assets-library://asset/asset.JPG?id=<UUID>&ext=JPG
    NSString *assetIdentifier = nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:assetURL resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"id"]) {
            assetIdentifier = item.value;
            break;
        }
    }

    if (!assetIdentifier) {
        // Try to extract from path if query parameter not found
        NSString *path = [assetURL path];
        NSArray *components = [path componentsSeparatedByString:@"="];
        if (components.count > 1) {
            assetIdentifier = components[1];
        }
    }

    if (!assetIdentifier || assetIdentifier.length == 0) {
        NSLog(@"[CDVAssetLibraryFilesystem] Could not extract asset identifier from URL: %@", urlString);
        callback(nil, nil, NOT_FOUND_ERR);
        return;
    }

    // Fetch PHAsset using the identifier
    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];

    if (fetchResult.count == 0) {
        NSLog(@"[CDVAssetLibraryFilesystem] No asset found for identifier: %@", assetIdentifier);
        callback(nil, nil, NOT_FOUND_ERR);
        return;
    }

    PHAsset *asset = fetchResult.firstObject;
    PHImageManager *imageManager = [PHImageManager defaultManager];

    // Request image or video data
    if (asset.mediaType == PHAssetMediaTypeImage) {
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.synchronous = NO;
        options.networkAccessAllowed = YES;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;

        [imageManager requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            if (imageData) {
                NSUInteger size = (end > start) ? (end - start) : imageData.length;
                NSRange range = NSMakeRange(start, MIN(size, imageData.length - start));
                NSData *subdata = [imageData subdataWithRange:range];

                NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)dataUTI, kUTTagClassMIMEType);
                callback(subdata, mimeType, NO_ERROR);
            } else {
                NSError *error = info[PHImageErrorKey];
                NSLog(@"[CDVAssetLibraryFilesystem] Error reading image: %@", error);
                callback(nil, nil, NOT_READABLE_ERR);
            }
        }];
    } else if (asset.mediaType == PHAssetMediaTypeVideo) {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.networkAccessAllowed = YES;
        options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;

        [imageManager requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *avAsset, AVAudioMix *audioMix, NSDictionary *info) {
            if ([avAsset isKindOfClass:[AVURLAsset class]]) {
                AVURLAsset *urlAsset = (AVURLAsset *)avAsset;
                NSError *error = nil;
                NSData *videoData = [NSData dataWithContentsOfURL:urlAsset.URL options:0 error:&error];

                if (videoData) {
                    NSUInteger size = (end > start) ? (end - start) : videoData.length;
                    NSRange range = NSMakeRange(start, MIN(size, videoData.length - start));
                    NSData *subdata = [videoData subdataWithRange:range];
                    callback(subdata, @"video/mp4", NO_ERROR);
                } else {
                    NSLog(@"[CDVAssetLibraryFilesystem] Error reading video: %@", error);
                    callback(nil, nil, NOT_READABLE_ERR);
                }
            } else {
                callback(nil, nil, NOT_READABLE_ERR);
            }
        }];
    } else {
        callback(nil, nil, NOT_READABLE_ERR);
    }
}

- (void)getFileMetadataForURL:(CDVFilesystemURL *)localURL callback:(void (^)(CDVPluginResult *))callback
{
    // MIGRATED TO PHOTOS FRAMEWORK FOR iOS 26
    NSURL *assetURL = [self assetLibraryURLForLocalURL:localURL];
    NSString *urlString = [assetURL absoluteString];

    // Extract asset identifier
    NSString *assetIdentifier = nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:assetURL resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"id"]) {
            assetIdentifier = item.value;
            break;
        }
    }

    if (!assetIdentifier) {
        NSString *path = [assetURL path];
        NSArray *pathComponents = [path componentsSeparatedByString:@"="];
        if (pathComponents.count > 1) {
            assetIdentifier = pathComponents[1];
        }
    }

    if (!assetIdentifier || assetIdentifier.length == 0) {
        NSLog(@"[CDVAssetLibraryFilesystem] Could not extract asset identifier from URL: %@", urlString);
        callback([CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsInt:NOT_FOUND_ERR]);
        return;
    }

    // Fetch PHAsset
    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];

    if (fetchResult.count == 0) {
        NSLog(@"[CDVAssetLibraryFilesystem] No asset found for identifier: %@", assetIdentifier);
        callback([CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsInt:NOT_FOUND_ERR]);
        return;
    }

    PHAsset *asset = fetchResult.firstObject;

    // Retrieve asset resources to get file size
    NSArray<PHAssetResource *> *resources = [PHAssetResource assetResourcesForAsset:asset];
    PHAssetResource *resource = resources.firstObject;

    NSMutableDictionary *fileInfo = [NSMutableDictionary dictionaryWithCapacity:5];

    // Get file size (approximate for photos)
    if (resource) {
        NSNumber *fileSize = [resource valueForKey:@"fileSize"];
        if (fileSize) {
            [fileInfo setObject:fileSize forKey:@"size"];
        } else {
            // Estimate size based on pixel dimensions for images
            if (asset.mediaType == PHAssetMediaTypeImage) {
                NSInteger estimatedSize = asset.pixelWidth * asset.pixelHeight * 4; // Rough estimate
                [fileInfo setObject:@(estimatedSize) forKey:@"size"];
            } else {
                [fileInfo setObject:@(0) forKey:@"size"];
            }
        }

        // Filename
        NSString *filename = resource.originalFilename ?: @"asset";
        [fileInfo setObject:filename forKey:@"name"];
        [fileInfo setObject:[CDVAssetLibraryFilesystem getMimeTypeFromPath:filename] forKey:@"type"];
    } else {
        [fileInfo setObject:@(0) forKey:@"size"];
        [fileInfo setObject:@"asset" forKey:@"name"];
        [fileInfo setObject:@"application/octet-stream" forKey:@"type"];
    }

    [fileInfo setObject:localURL.fullPath forKey:@"fullPath"];

    // Creation/modification date
    NSDate *creationDate = asset.creationDate ?: [NSDate date];
    NSNumber *msDate = @([creationDate timeIntervalSince1970] * 1000);
    [fileInfo setObject:msDate forKey:@"lastModifiedDate"];

    callback([CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:fileInfo]);
}
@end
