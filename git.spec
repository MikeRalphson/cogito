Name: 		cogito
Version: 	0.8
Release: 	2
Vendor: 	Petr Baudis <pasky@ucw.cz>
Summary:  	Git core and tools
License: 	GPL
Group: 		Development/Tools
URL: 		http://kernel.org/pub/software/scm/cogito/
Source: 	http://kernel.org/pub/software/scm/cogito/%{name}-%{version}.tar.bz2
Provides: 	cogito = %{version}
Obsoletes:	git
BuildRequires:	zlib-devel, openssl-devel, curl-devel
BuildRoot:	%{_tmppath}/%{name}-%{version}-root
Prereq: 	sh-utils, diffutils, rsync, rcs, mktemp >= 1.5

%description
GIT comes in two layers. The bottom layer is merely an extremely fast
and flexible filesystem-based database designed to store directory trees
with regard to their history. The top layer is a SCM-like tool which
enables human beings to work with the database in a manner to a degree
similar to other SCM tools (like CVS, BitKeeper or Monotone).

%prep
%setup -q

%build

make

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT prefix=%{_prefix} install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/usr/bin/*
%doc README README.reference COPYING Changelog

%changelog
* Wed Apr 27 2005 Terje Rosten <terje.rosten@ntnu.no> 0.8-2
- Doc files
- Use %%{_prefix} macro
- Drop -n option to %%setup macro

* Mon Apr 25 2005 Chris Wright <chrisw@osdl.org> 0.8-1
- Update to cogito, rename package, move to /usr/bin, update prereqs

* Mon Apr 25 2005 Chris Wright <chrisw@osdl.org> 0.7-1
- Update to 0.7

* Thu Apr 21 2005 Chris Wright <chrisw@osdl.org> 0.6.3-1
- Initial rpm build
