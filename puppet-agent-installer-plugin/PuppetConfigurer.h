//
//  PuppetConfigurer.h
//  puppet-agent-installer-plugin
//
//  Copyright (c) 2015 Puppet Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

// PuppetConfigurer is a tiny class that does one thing:
// Write a file containing the user's entry of Puppet Master hostname and Puppet Agent certname that can be sourced by the puppet postinstall script.

@interface PuppetConfigurer : NSObject

@property NSString* agentCertname;
@property NSString* masterHostname;


/* Display a warning window with the title message and the content information, with a single button, 'OK'. */
- (void) displayConfigurationWarning:(NSString *)message :(NSString *)information;

/* Create a directory in which to house the configuration file that will supply puppet's defaults.
 The directory will be in targetVolume if targetVolume is not NULL, otherwise it will default to '/'. */
- (NSString *) createInstallerDirectory: (NSString*)targetVolume;

/* Create a configuration file in installerDir containing containing two lines, each of which will establish
 variables that puppet will use to set configuration values. */
- (void) writeConfigFile: (NSString *)installerDir;

/* Return the Home directory of the user running the installer */
- (NSString *) userHomeDirectory;

/* Attempt to remove an existing pending installer directory */
- (BOOL) removeExistingInstallerDirectory: (NSString *)path;

/* Attempt to create a pending installer directory */
- (BOOL) attemptInstallerDirectoryCreation: (NSString *)path :(BOOL)removeExisting;


@end
