//
//  PuppetConfigurer.m
//  puppet-agent-installer-plugin
//
//  Created by moses on 1/16/14.
//  Copyright (c) 2015 Puppet Labs. All rights reserved.
//

#import "PuppetConfigurer.h"

@implementation PuppetConfigurer


// Warn the user that we were unable to do something, they should do it themselves
- (void)displayConfigurationWarning:(NSString *)message :(NSString *)information
{
    NSAlert *warnDialog = [[NSAlert alloc] init];
    [warnDialog addButtonWithTitle:@"OK"];
    [warnDialog setMessageText:message];
    [warnDialog setInformativeText:information];
    [warnDialog setAlertStyle:NSInformationalAlertStyle];
    [warnDialog runModal];
}

// Return the home directory of the user running the installer
- (NSString *) userHomeDirectory
{
    NSProcessInfo *proc = [[NSProcessInfo alloc]init];
    return [[proc environment]objectForKey:@"HOME"];
}

// Attempt to remove an existing pending installer directory
- (BOOL) removeExistingInstallerDirectory: (NSString *) path
{
    NSFileManager *fileManager = [[NSFileManager alloc]init];
    
    if ([fileManager removeItemAtPath:path error:nil])
    {
        return YES;
    }
    else
    {
        [self displayConfigurationWarning:[NSString stringWithFormat:@"%@ exists", path] :[NSString stringWithFormat:@"The directory %@ already exists and could not be removed - please remove it and retry installation.", path]];
        exit(1);
    }
}

// Attempt to create a pending installer directory. If removeExisting is YES, directory will be removed if it already exists.
- (BOOL) attemptInstallerDirectoryCreation: (NSString *)path :(BOOL)removeExisting
{
    NSFileManager *fileManager = [[NSFileManager alloc]init];
    NSMutableDictionary *installerDirAttributes = [[NSMutableDictionary alloc] init];
    
    if (removeExisting && [fileManager fileExistsAtPath:path])
    {
        [self removeExistingInstallerDirectory:path];

    }

    [installerDirAttributes setObject:[NSNumber numberWithInt:960] forKey:NSFilePosixPermissions]; /*960 is Decial for 1700 octal*/
    [installerDirAttributes setObject:@"admin" forKey:NSFileGroupOwnerAccountName];
    
    if ([fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:installerDirAttributes error:nil])
    {
        return YES;
    }
    else
    {
        [self displayConfigurationWarning:@"Unable to configure Puppet" :@"After install, please set the 'certname' and 'server' entries in the 'main' section of /etc/puppetlabs/puppet/puppet.conf"];
        return NO;
    }
}

-(NSString *) createInstallerDirectory:(NSString *)targetVolume
{
    /* Where we actually put the installer config directory is one of the most critical and difficult problems to solve in this entire problemset.
     We have to consider both security and the user experience when deciding this.
     
     THE PROBLEM:
     
     * We need to obtain the hostname of the master and the certname of the agent from the GUI install pane and somehow use this information to configure puppet.

     CONSTRAINTS/ASSUMPTIONS:
     
     * This installer plugin cannot pass information in memory to the pre/post install scripts of any of the packages in Puppet agent
     
     * This installer plugin runs as the user that double-clicked the package, with the effective permissions of that user (which in OSX are going to be basic user permissions, not root, unless someone logged into the OSX GUI as root)
     
     * A component package, such as puppet, can have preinstall and postinstall scripts that do package configuration. These scripts run as root. We want to use these scripts to configure puppet.
     
     * The Installer and its plugins and the preinstall/postinstall scripts run in entirely separate process trees, and as such we cannot trace the process of a running postinstall/preinstall script back to the installer plugin process
     
     * Elevating privelges can only be done via Apple's circuitous and terrible authorization frameworks, prompting the user for a 'sudo' password

     * We can place the GUI anywhere in the install process, e.g. both before and after the installation of packages (and thus before or after our puppet preinstall/postinstall scripts run)
     
     * The package containing the GUI plugin and the package containing puppet and its preinstall/postinstall scripts are in two distinct, randomized locations on the file system. Neither knows the file system location of the other.
     
     * The only discernable piece of information shared between the installer plugin and the scripts is the HOME directory of the user logged into the GUI, present in the environment. If the user logged into the GUI is root, this information is not populated.
     
    
     IMPLICATIONS:

     * We do not want to escalate privileges because it is very difficult and also a poor user experience - the user already has to do this during the 'install packages' step.
     
     * We can't pass the information via process environment or any other cross-process communication
     
     * As such, we need to do it via the file system
     
     * We can't use a random tempdir, because only the plugin will know where the tempdir is. We have no way to pass the tempdirs location in the file system to the package preinstall/postinstall scripts
     
     * We thus need to use a pre-determined file system location that is accessible to the user
     
     * We thus cannot write to a location accessible only with privilege escalation
     
     * We thus must either write in /tmp with a known path, or to the user's home directory
     
     * Writing in /tmp with a known path as an unprivileged user, and then using that information to configure puppet as root is a security vulnerabilty:
     
     * If we set the sticky bit of the file(s) we write and the group ownership of the files we write to 'admin', we effectively disable anything but a process running as the user or an admin from modifying the file
     
     * We should overwrite a pre-existing config file to ensure it's ours, or fail if we cannot do so. We should not configure puppet with a pre-existing config file.
     
     * Since we know the user's home directory, we can attempt to write to the standard User-level cache directory, ~/Library/Caches, instead of /tmp. This gives us additional assurance that only the user running the installer could access the information.
     
     */

    NSString *home;
    NSString *pendingInstallerDir;
    BOOL success = NO;
    
    home = [self userHomeDirectory];
    if (home == (id)[NSNull null])
    {
        home = @"/var/root";
    }

    if (!(targetVolume == (id)[NSNull null] || targetVolume.length == 0 || [targetVolume isEqualToString:@"/"]))
    {
         home = [NSString stringWithFormat:@"%@%@", targetVolume, home];
    }
    
    pendingInstallerDir = [NSString stringWithFormat:@"%@%@", home, @"/Library/Caches/puppet-agent-installer"];
    success = [self attemptInstallerDirectoryCreation:pendingInstallerDir :YES];
    
    if (success)
    {
        return pendingInstallerDir;
    }
    else
    {
        return nil;
    }
}

-(void) writeConfigFile:(NSString*)installerDir
{
    if (!(installerDir == (id)[NSNull null] || installerDir.length == 0))
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *configFile = [[NSURL URLWithString:installerDir] URLByAppendingPathComponent:@"PuppetagentInterviewConfiguration.txt"];
    
        NSString *configFileContents = [[NSString alloc] initWithFormat:@"PUPPET_MASTER_HOSTNAME=%@\nPUPPET_AGENT_CERTNAME=%@", [self masterHostname], [self agentCertname]];
        NSData *configFileData = [configFileContents dataUsingEncoding:NSUTF8StringEncoding];
    
        NSMutableDictionary *configFileAttributes = [[NSMutableDictionary alloc] init];
    
        [configFileAttributes setObject:[NSNumber numberWithInt:896] forKey:NSFilePosixPermissions]; /*896 is Decimal for 1600 octal*/
        [configFileAttributes setObject: @"admin" forKey:NSFileGroupOwnerAccountName];
    

        if (!([fileManager createFileAtPath:[configFile path] contents:configFileData attributes:configFileAttributes]))
        {
            [self displayConfigurationWarning:@"Unable to configure Puppet" :@"Please set the certname and server entries in the section main of /etc/puppetlabs/puppet/puppet.conf"];
        }
    }
}

@end
