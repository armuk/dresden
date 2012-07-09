#
# Variables needed to build the kernel module
#
name      = dresden
src_files = dresden_core.c module_notifier_event.c

obj-m += $(name).o
$(name)-objs := $(src_files:.c=.o)


#
# Distributions which src rpms are built for by default
# The corresponding spec file is needed: DIST/$(name).spec
#
DISTS    = slc5 slc6

#
# variables for all external commands (we try to be verbose)
#

GIT      = git
PERL     = perl
RPMBUILD = rpmbuild
SED      = sed

all: srcrpm

#+++############################################################################
#                                                                              #
# version management                                                           #
#                                                                              #
#---############################################################################

#
# internal targets
#

.PHONY: _increment_version _increment_release _update_spec _git_commit_tag

_increment_version:
	@$(PERL) -pi -e 'die("invalid version: $$_\n") unless \
	  s/^(\d+)\.(\d+)(.*?)$$/sprintf("%d.%d%s", $$1+1, 0, $$4)/e' VERSION

_increment_release:
	@$(PERL) -pi -e 'die("invalid version: $$_\n") unless \
	  s/^(\d+)\.(\d+)(.*?)$$/sprintf("%d.%d%s", $$1, $$2+1, $$4)/e' VERSION

_update_spec: $(DISTS:=.spec)

%.spec: dist.%/$(name).spec
	@version=`cat VERSION`; \
	$(SED) -i -e "s/^\(%define kmod_driver_version\s\+\)\S\+\s*$$/\1$$version/" $<

_git_commit_tag:
	@version=`cat VERSION`; \
	$(GIT) commit -a -m "global commit for version $$version" || exit 1; \
	tag=`$(PERL) -pe 's/^/v/; s/\./_/g' VERSION`; \
	$(GIT) tag $$tag || exit 1; \
        $(GIT) push || exit 1; \
        $(GIT) push origin $$tag || exit 1; \
	echo "New version is $$version (tag $$tag)"

#
# standard targets
#

version:    _increment_version _update_spec _git_commit_tag

release:    _increment_release _update_spec _git_commit_tag

#+++############################################################################
#                                                                              #
# Simple build                                                                 #
#                                                                              #
#---############################################################################

all:
	$(MAKE) -C /lib/modules/`uname -r`/build M=`pwd` modules
clean:
	$(MAKE) -C /lib/modules/`uname -r`/build M=`pwd` clean
	$(RM) Module.markers modules.order

#+++############################################################################
#                                                                              #
# RPMs building                                                                #
#                                                                              #
#---############################################################################


srcrpm: $(DISTS:=.srcrpm) $(DISTS:=.clean)

slc5.srcrpm: dist.slc5/$(name).spec dist.slc5/$(name).tgz
	@$(RPMBUILD) --define "_sourcedir ${PWD}/dist.slc5" --define "_srcrpmdir ${PWD}" --define "dist .slc5" --define '_source_filedigest_algorithm 1' --define '_binary_filedigest_algorithm 1' --define '_binary_payload w9.gzdio' -bs $<

%.srcrpm: dist.%/$(name).spec dist.%/$(name).tgz
	@$(RPMBUILD) --define "_sourcedir ${PWD}/dist.$*" --define "_srcrpmdir ${PWD}" --define "dist .$*" -bs $<

%.tgz:
	@version=`cat VERSION`; \
	mkdir $(name)-$$version; \
	rsync -a --exclude $(name)-$$version --exclude ".git*" --exclude "*.rpm" --exclude "*.tgz" --exclude "dist.*" --exclude webpage . $(name)-$$version/; \
	tar -zchf $*-$$version.tgz $(name)-$$version/; \
	rm -rf $(name)-$$version/

clean: $(DISTS:=.clean)
	@rm -f *.rpm

%.clean:
	@rm -f dist.$*/*.tgz