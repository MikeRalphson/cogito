Name: 		git
Version: 	0.6.3
Release: 	1
Vendor: 	Petr Baudis <pasky@ucw.cz>
Summary:  	Git core and tools
License: 	GPL
Group: 		Development/Tools
URL: 		http://pasky.or.cz/~pasky/dev/git/
Source: 	http://pasky.or.cz/~pasky/dev/git/%{name}-pasky-%{version}.tar.bz2
Provides: 	git = %{version}
BuildRequires:	zlib-devel openssl-devel
BuildRoot:	%{_tmppath}/%{name}-%{version}-root
Prereq: 	sh-utils diffutils

%description
GIT comes in two layers. The bottom layer is merely an extremely fast
and flexible filesystem-based database designed to store directory trees
with regard to their history. The top layer is a SCM-like tool which
enables human beings to work with the database in a manner to a degree
similar to other SCM tools (like CVS, BitKeeper or Monotone).

%prep
%setup -q -n %{name}-pasky-%{version}

%build

make

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT prefix=/usr/local install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/usr/local/bin/*
#%{_mandir}/*/*

%changelog
* Thu Apr 21 2005 Chris Wright <chrisw@osdl.org> 0.6.3-1
- Initial rpm build
