Summary: Applet that shows traffic on a network device
Name: mate_netspeed_applet
Version: 1.2.0
Release: 1
URL: https://github.com/stefano-k/mate-netspeed/
Source0: %{name}-%{version}.tar.gz
License: GPL
Group: Mate/Applets
BuildRoot: %{_tmppath}/%{name}-%{version}-root
Prefix: %{_prefix}
BuildRequires: pkgconfig
BuildRequires: intltool
BuildRequires: mate-panel-devel
BuildRequires: libmateui-devel
BuildRequires: libgtop-devel

%description
mate_netspeed_applet is a little MATE applet that shows the traffic on a
specified network device (for example eth0) in kbytes/s.

%prep
%setup -q

%build
%configure
%__make

%install
rm -rf %{buildroot}
%makeinstall
%find_lang mate_netspeed_applet

%clean
rm -rf %{buildroot}

%files -f mate_netspeed_applet.lang
%defattr(-,root,root)
%doc AUTHORS COPYING NEWS README TODO
%{prefix}/libexec/*
%{prefix}/lib/matecomponent/servers/*
%{prefix}/share/pixmaps/*