//
//  puppet_agent_installer_pluginPane.m
//  puppet-agent-installer-plugin
//
//  Copyright (c) 2015 Puppet Labs. All rights reserved.
//

#import "puppet_agent_installer_pluginPane.h"

@implementation puppet_agent_installer_pluginPane

- (NSString *)title
{
	return [[NSBundle bundleForClass:[self class]] localizedStringForKey:@"PaneTitle" value:nil table:nil];
}


- (void)didEnterPane:(InstallerSectionDirection)dir
{
    NSString *config = @"/etc/puppetlabs/puppet/puppet.conf";
    NSString *targetVolume = [[[self section]installerState]targetPath];
    if (!(targetVolume == (id)[NSNull null] || targetVolume.length == 0 || [targetVolume isEqualToString:@"/"]))
    {
        config = [NSString stringWithFormat:@"%@%@", targetVolume, config];
    }

    // If the puppet.conf exists already, we skip this check
    if ([[NSFileManager defaultManager] fileExistsAtPath:config])
    {
        if (dir == InstallerDirectionForward)
        {
            [self gotoNextPane];
        }
        else
        {
            [self gotoPreviousPane];
        }
    }
    // Initialize the text fields to empty
    [puppetMasterHostname setStringValue:@"puppet.localdomain"];
    [puppetAgentCertname setStringValue:[[NSHost currentHost] name].lowercaseString];
    
    // Enable the continue and go back buttons
    [self setNextEnabled:YES];
    [self setPreviousEnabled:YES];
    
}


- (BOOL)shouldExitPane:(InstallerSectionDirection)dir
{
    
    NSString *masterHostname = [puppetMasterHostname stringValue];
    NSString *agentCertname = [puppetAgentCertname stringValue].lowercaseString;
    NSString *targetPath = [[[self section]installerState]targetPath];
    
    PuppetConfigurer *configurer = [[PuppetConfigurer alloc]init];
    
    configurer.masterHostname = masterHostname;
    configurer.agentCertname = agentCertname;
    
    [configurer writeConfigFile:[configurer createInstallerDirectory:targetPath]];
    
    
    return YES;
}


- (BOOL) shouldLoad
{
    return NO;
}



@end
