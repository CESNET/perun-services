#!/usr/bin/make -f
SHELL=/bin/bash
maintainer_name="Michal Stava"
maintainer_email="stavamichal@gmail.com"
comma:=,
empty:=
space:=$(empty) $(empty)
package_prefix_name=perun-slave-
meta_package_name=full
base_package_name=base
processes := $(strip $(base_package_name)$(space)$(filter-out %.deb,$(wildcard process-*)))
format="3.0 (native)"

.PHONY: all processes meta clean $(processes)

all: processes meta

processes: $(processes)

meta:
	@cd meta && PACKAGE_NAME=$(package_prefix_name)$(meta_package_name) DEPENDENCIES="$(subst $(space),$(comma)$(space),$(addprefix $(package_prefix_name),$(processes)))" VERSION=`head -n 1 changelog | sed -e 's/.*\([0-9]\+[.][0-9]\+[.][0-9]\+\).*/\1/'` envsubst < ../templates/equivs/control > control
	@cd meta && if [ -s short_desc ]; then echo "Description: `cat short_desc`" >> control; fi
	@cd meta && echo "Conflicts: perun-slave" >> control;
	@cd meta && if [ -s short_desc -a -s long_desc ]; then sed 's/^/ /g' long_desc >> control; fi
	equivs-build meta/control
	@rm meta/control
	@echo "Generate spec file for meta..."
	@./generate_rpm.sh meta

$(processes):
	@echo "Generating deb package for $@..."
	@cd $@ && NAME=$(subst process-,,$@) envsubst < ../templates/Makefile > Makefile
	@cd $@ && if [ $@ != $(base_package_name) ]; then cat ../templates/makefile_conf_part >> Makefile; fi
	@cd $@ && if [ -d lib ]; then cat ../templates/makefile_lib_part >> Makefile; fi
	cd $@ && DEBEMAIL=$(maintainer_email) DEBFULLNAME=$(maintainer_name) dh_make -i -y -n -p "$(package_prefix_name)$@_`head -n 1 changelog | sed -e 's/.*\([0-9]\+[.][0-9]\+[.][0-9]\+\).*/\1/'`" -t "$(realpath templates/dh_make)" --createorig
	@cd $@/debian && rm *.ex *.EX README.*
	@cd $@ && if [ -s changelog ]; then cp changelog ./debian/; fi
	@cd $@ && echo -en "\noverride_dh_builddeb:\n\tdh_builddeb -- -Zgzip\noverride_dh_gencontrol:\n\tdh_gencontrol -- -Vmisc:Depends=\"`cat dependencies`\"" >> ./debian/rules;
	@cd $@ && echo "Conflicts: perun-slave" >> debian/control;
	@cd $@ && if [ -s short_desc ]; then echo "Description: `cat short_desc`" >> debian/control; fi
	@cd $@ && if [ -s short_desc -a -s long_desc ]; then sed 's/^/ /g' long_desc >> debian/control; fi
	@echo $(format) > $@/debian/source/format
	cd $@ && debuild -us -uc
	@echo "Cleaning after $@ building process..."
	@rm -rf "$@/"{Makefile,debian}
	@rm -f "$(package_prefix_name)$@_"*.{build,changes,dsc,tar.gz,tar.xz,buildinfo}
	@echo "Generate spec file for $@..."
	@./generate_rpm.sh $@


clean:
	@rm -f *.{deb,build,changes,dsc,tar.gz,tar.xz,rpm,spec,tgz,buildinfo}
	@rm -rf {$(subst $(space),$(comma),$(processes))}/{Makefile,debian}
