<?php
/**
 * i-MSCP InstantSSH plugin
 * Copyright (C) 2014 Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

require_once 'InstantSSH/Validate/SshAuthOptions.php';

return array(
	// Default SSH authentication options added for any new customer key.
	//
	// See man authorized_keys for list of allowed authentication options.
	// eg. command="dump /home",no-pty,no-port-forwarding
	//
	// Note that any option defined here must be specified in the allowed_ssh_auth_options parameter (see below)
	'default_ssh_auth_options' => 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding',

	//
	// SSH authentication options that customers are allowed to define when they are allowed to override default.
	//
	// Valid options are:
	//
	// \InstantSSH\Validate\SshAuthOptions::ALL (for all options)
	// \InstantSSH\Validate\SshAuthOptions::CERT_AUTHORITY (for the cert-authority option)
	// \InstantSSH\Validate\SshAuthOptions::COMMAND (for the 'command' option)
	// \InstantSSH\Validate\SshAuthOptions::ENVIRONMENT (for the 'environment' option)
	// \InstantSSH\Validate\SshAuthOptions::FROM (for the 'from' option)
	// \InstantSSH\Validate\SshAuthOptions::NO_AGENT_FORWARDING (for the 'no-agent-forwarding' option)
	// \InstantSSH\Validate\SshAuthOptions::NO_PORT_FORWARDING (for the 'no-port-forwarding' option)
	// \InstantSSH\Validate\SshAuthOptions::NO_PTY (for the 'no-pty' option)
	// \InstantSSH\Validate\SshAuthOptions::NO_USER_RC (for the 'no-user-rc' option)
	// \InstantSSH\Validate\SshAuthOptions::NO_X11_FORWARDING (for the 'no-x11-forwarding' option)
	// \InstantSSH\Validate\SshAuthOptions::PERMITOPEN (for the 'permitopen' option)
	// \InstantSSH\Validate\SshAuthOptions::PRINCIPALS (for the 'principals' option)
	// \InstantSSH\Validate\SshAuthOptions::TUNNEL (for the 'tunnel' option)
	'allowed_ssh_auth_options' => array(
		\InstantSSH\Validate\SshAuthOptions::ALL
	),

	// Shell for SSH users
	//
	// See man shells for further details. Please, do not change this value if you do not know what you are doing
	'shell' => '/bin/bash',

	##
	### Jailed shell configuration options
	##

	// root jail directory (default /var/chroot/InstantSSH)
	//
	// Full path to the root jail directory. Be sure that the partition in which this directory is living has enough
	// space to host the jails.
	//
	// IMPORTANT: You must never change this parameter while updating the plugin to a new version.
	'root_jail_dir' => '/var/chroot/InstantSSH',

	// Shared jail (default true)
	//
	// When the value is true, only one jail will be created for all customers. A shared jail doesn't mean that a
	// customer will be able to read, modify or delete files of another customer. This simply mean that only one jail
	// will be created. Having a jail for each customer is interesting only when you want provide a different set of
	// commands for them.
	//
	// Note: Per customer application feature is not yet implemented.
	'shared_jail' => true,

	// Preserved files (default /home)
	//
	// The plugin won't try to remove files or directories inside jails if their path begins with one of the strings
	// in this list.
	//
	// This parameter can be also defined in the application sections (see below).
	//
	// WARNING: Do not remove the default /home entry if you don't know what you are doing.
	'preserve_files' => array(
		'/home'
	),

	# Application section (default imscpbase)
	#
	# This is the list of application sections which are used to create/update the jails (see below).
	#
	# By default only the imscpbase application section is added, which allows to build very restricted jailed shell
	# environments (restricted set of commands)
	'apps_sections' => array(
		'imscpbase'
	),

	# Predefined application sections
	#
	# Below, you can find the predefined application sections. Those sections are used to build new jails or update them.
	# You can select any of the sections below by adding them into the apps_sections configuration options.
	#
	# It's not recommended to change any of these sections without understanding how they are working. Once you know how
	# they are working, you can define your own sections.
	#
	# Important: Any command, file, library or package listed in the application sections must be already installed on
	# your system, else it will be ignored.

	// uidbasics section
	// Provide common files for all jails that need user/group information
	'uidbasics' => array(
		'paths' => array(
			'/lib/libnsl.so.1', '/lib64/libnsl.so.1', '/lib/libnss*.so.2', '/lib64/libnss*.so.2',
			'/lib/i386-linux-gnu/libnsl.so.1', '/lib/i386-linux-gnu/libnss*.so.2', '/lib/x86_64-linux-gnu/libnsl.so.1',
			'/lib/x86_64-linux-gnu/libnss*.so.2', '/etc/nsswitch.conf', '/etc/ld.so.conf'
		)
	),

	// netbasics section
	// Provide common files for all jails that need any internet connectivity
	'netbasics' => array(
		'path' => array(
			'/lib/libnss_dns.so.2', '/lib64/libnss_dns.so.2', '/etc/resolv.conf', '/etc/host.conf', '/etc/hosts',
			'/etc/protocols', '/etc/services'
		)
	),

	// logbasics section
	// Provide timezone information and log sockets
	'logbasics' => array(
		'paths' => '/etc/localtime',
		'need_logsocket' => true
	),

	// cvs section
	// Provide concurrent Versions System
	'cvs' => array(
		'commands' => array(
			'cvs'
		),
		'devices' => array(
			'/dev/null'
		)
	),

	// git section
	// Provide Git - Distributed revision control and source code management (SCM) system
	'git' => array(
		'paths' => array(
			'/usr/bin/git*', '/usr/lib/git-core'
		),
		'commands' => array(
			'basename', 'uname'
		),
		'include_apps_sections' => array(
			'editors', 'perl'
		)
	),

	// scp section
	// Provide ssh secure copy
	'scp' => array(
		'commands' => array(
			'scp'
		),
		'include_apps_sections' => array(
			'netbasics', 'uidbasics'
		),
		'devices' => array(
			'/dev/urandom'
		)
	),

	// sftp section
	// Provide ssh secure ftp
	'sftp' => array(
		'paths' => array(
			'/usr/lib/sftp-server', '/usr/libexec/openssh/sftp-server', '/usr/lib/misc/sftp-server',
			'/usr/libexec/sftp-server', '/usr/lib/openssh/sftp-server'
		),
		'include_apps_sections' => array(
			'netbasics', 'uidbasics'
		),
		'devices' => array(
			'/dev/urandom', '/dev/null'
		)
	),

	// ssh section
	// Provide ssh secure shell
	'ssh' => array(
		'commands' => array(
			'ssh'
		),
		'include_apps_sections' => array(
			'netbasics', 'uidbasics'
		),
		'devices' => array(
			'/dev/urandom', '/dev/tty', '/dev/null'
		)
	),

	// rsync section
	// Provide rsync command
	'rsync' => array(
		'commands' => array(
			'rsync'
		),
		'include_apps_sections' => array(
			'netbasics', 'uidbasics'
		)
	),

	// procmail section
	// Provide procmail mail delivery agent
	'procmail' => array(
		'commands' => array(
			'procmail', 'sh'
		),
		'devices' => array(
			'/dev/null'
		)
	),

	// basicshell section
	// Provide bash based shell with several basic utilities
	'basicshell' => array(
		'paths' => array(
			'/etc/motd', '/etc/issue', '/etc/bash.bashrc', '/etc/bashrc', '/etc/profile', '/usr/lib/locale/C.UTF-8'
		),
		'commands' => array(
			'sh', 'bash', 'ls', 'cat', 'chmod', 'mkdir', 'cp', 'cpio', 'date', 'dd', 'echo', 'egrep', 'false',
			'fgrep', 'grep', 'gunzip', 'gzip', 'ln', 'ls', 'mkdir', 'mktemp', 'more', 'mv', 'pwd', 'rgrep', 'rm',
			'rmdir', 'sed', 'sh', 'sleep', 'sync', 'tar', 'touch', 'true', 'uncompress', 'zcat'
		),
		'users' => array(
			'root'
		),
		'groups' => array(
			'root'
		),
		'include_apps_sections' => array(
			'uidbasics'
		),
		'packages' => array(
			'coreutils'
		),
		'include_pkg_deps' => true
	),

	// midnightcommander section
	// Midnight Commander
	'midnightcommander' => array(
		'paths' => array(
			'/usr/share/mc'
		),
		'commands' => array(
			'mc', 'mcedit', 'mcview'
		),
		'include_apps_sections' => array(
			'basicshell', 'terminfo'
		)
	),

	// extendedshell section
	// Provide bash shell including things like awk, bzip, tail, less
	'extendedshell' => array(
		'commands' => array(
			'awk', 'bzip2', 'bunzip2', 'ldd', 'less', 'clear', 'cut', 'du', 'find', 'head', 'less', 'md5sum', 'nice',
			'sort', 'tac', 'tail', 'tr', 'sort', 'wc', 'watch', 'whoami'
		),
		'include_apps_sections' => array(
			'basicshell', 'midnightcommander', 'editors'
		)
	),

	// terminfo section
	// Provide terminfo databases, required for example for ncurses or vim
	'terminfo' => array(
		'paths' => array(
			'/etc/terminfo', '/usr/share/terminfo', '/lib/terminfo'
		)
	),

	// editors section
	// Provide vim, joe, nano and pico
	'editors' => array(
		'paths' => array(
			'/etc/vimrc', '/etc/joe', '/usr/share/vim', '/usr/bin/pico'
		),
		'commands' => array(
			'joe', 'nano', 'vi', 'vim', 'pico'
		)
	),

	// netutils section
	// Provide several internet utilities like wget, ftp, rsync, scp, ssh
	'netutils' => array(
		'commands' => array(
			'wget', 'lynx', 'ftp', 'host', 'rsync', 'smbclient'
		),
		'include_apps_sections' => array(
			'netbasics', 'ssh', 'sftp', 'scp'
		)
	),

	// apacheutils section
	// Provide htpasswd utility
	'apacheutils' => array(
		'commands' => array(
			'htpasswd'
		)
	),

	// section extshellplusnet
	// alias for extendedshell + netutils + apacheutils
	'extshellplusnet' => array(
		'include_apps_sections' => array(
			'extendedshell', 'netutils', 'apacheutils'
		)
	),

	// perl section
	// Provide the perl interpreter and libraries
	'perl' => array(
		'paths' => array(
			'/usr/lib/perl', '/usr/lib/perl5', '/usr/share/perl', '/usr/share/perl5'
		),
		'commands' => array(
			'perl'
		)
	),

	// xauth section
	// Provide support for X authentication to work
	'xauth' => array(
		'paths' => array(
			'/usr/bin/X11/xauth', '/usr/X11R6/lib/X11/rgb.txt', '/etc/ld.so.conf'
		)
	),

	// xclients section
	// Provide minimal files for X clients
	'xclients' => array(
		'paths' => array(
			'/usr/X11R6/lib/X11/rgb.txt'
		),
		'include_apps_sections' => array(
			'xauth'
		)
	),

	// vncserver section
	// Provide the VNC server program
	'vncserver' => array(
		'paths' => array(
			'Xvnc', 'Xrealvnc', '/usr/X11R6/lib/X11/fonts/'
		),
		'include_apps_sections' => array(
			'xclients'
		)
	),

	// ping section
	// Provide the ping command
	'ping' => array(
		'commands' => array(
			'ping'
		)
	),

	// xterm section
	// Provide xterm
	'xterm' => array(
		'paths' => array(
			'/usr/bin/X11/xterm', '/usr/share/terminfo', '/etc/terminfo'
		),
		'devices' => array(
			'/dev/pts/0', '/dev/pts/1', '/dev/pts/2', '/dev/pts/3', '/dev/pts/4', '/dev/ptyb4', '/dev/ptya4',
			'/dev/tty', '/dev/tty0', '/dev/tty4'
		)
	),

	// mysqlclient section
	// Provide MySQL client
	'mysqlclient' => array(
		'commands' => array(
			'mysql'
		),
		'users' => array(
			'mysql'
		),
		'groups' => array(
			'mysql'
		),
		'include_apps_sections' => array(
			'netbasics', 'uidbasics'
		),
		'mounts' => array(
			'/var/run/mysqld' => '/var/run/mysqld'
		)
	),

	// imscpbase section
	// Provide pre-selected application sections, users and groups for i-MSCP jailed shell
	'imscpbase' => array(
		'users' => array(
			'root', 'www-data'
		),
		'groups' => array(
			'root', 'www-data'
		),
		'include_apps_sections' => array(
			'extendedshell', 'netutils'
		)
	)
);
