//
//  puppet_agent_installer_pluginPane.h
//  puppet-agent-installer-plugin
//
//  Copyright (c) 2015 Puppet Labs. All rights reserved.
//

#import <InstallerPlugins/InstallerPlugins.h>
#import "PuppetConfigurer.h"

@interface puppet_agent_installer_pluginPane : InstallerPane

{
    IBOutlet NSTextField *puppetMasterHostname;
    IBOutlet NSTextField *puppetAgentCertname;
}

@end
