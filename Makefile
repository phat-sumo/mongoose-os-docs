all: sidebar.html # apps

.PHONY: sidebar.html api/core api

APPSMD = quickstart/apps.md
TMP = /tmp/.tmp.mos.yml
apps:
	curl -s https://api.github.com/orgs/mongoose-os-apps/repos?per_page=200 |\
		perl -nle 'print $$1 if /"full_name": "(.*)"/' > /tmp/repos.txt
	echo '# Example apps' > $(APPSMD)
	echo '|  GitHub repo  | Description | Author |' >> $(APPSMD)
	echo '|  ----  | ----------- | --- |' >> $(APPSMD)
	sort /tmp/repos.txt | while read REPO ; do \
		curl -s https://raw.githubusercontent.com/$$REPO/master/mos.yml > $(TMP); \
		echo $$REPO ; \
		echo "| [$${REPO#*/}](https://github.com/$$REPO) | $$(cat $(TMP) | perl -nle 'print $$1 if /^description: (.*)/') | $$(cat $(TMP) | perl -nle 'print $$1 if /^author: (.*)/') | " >> $(APPSMD) ;\
		done

DEV ?= ../cesanta.com
INC ?= $(DEV)/fw/include
MJS ?= $(DEV)/mos_libs/mjs
api/core:
	@rm -rf $@
	@mkdir -p $@
	@touch $@/index.md
	@(cd $(INC) && ls *.h) | while read F; do node tools/genapi.js $(INC)/$$F $@/$$F.md "" $(MJS) >> $@/index.md; done
	@node tools/genapi.js $(DEV)/frozen/frozen.h $@/frozen.h.md JSON >> $@/index.md
	@node tools/genapi.js $(DEV)/common/cs_dbg.h $@/cs_dbg.h.md Logging >> $@/index.md
	@node tools/genapi.js $(DEV)/common/mbuf.h $@/mbuf.h.md Membuf >> $@/index.md
	@node tools/genapi.js $(DEV)/common/mg_str.h $@/mg_str.h.md String >> $@/index.md

LIBS ?= /tmp/libs
LIBSINDEX ?= /tmp/libs.txt
api:
	@#node -e 'require("js-yaml")' || npm i -g js-yaml
	@test -f $(LIBSINDEX) || curl -s https://api.github.com/orgs/mongoose-os-libs/repos?per_page=200 | perl -nle 'print $$1 if /"full_name": "(.*)"/' | sort > $(LIBSINDEX)
	@mkdir -p $(LIBS)
	@cat $(LIBSINDEX) | head -2 | while read REPO ; \
		do echo $$REPO; \
		R=$(LIBS)/$$(basename $$REPO); \
		test -d $$R && (cd $$R && git pull --quiet) || git clone --quiet https://github.com/$$REPO $$R; \
		CATEGORY=$$(perl -ne 'print $1 if /docs:$(.+?):$(.+)/' $$R/mos.yml); \
		TITLE=$$(perl -ne 'print $1 if /docs:$(.+?):$(.+)/' $$R/mos.yml); \
		test -d $@/$$CATEGORY || mkdir -p $@/$$CATEGORY ; touch $@/$$CATEGORY/index.md; \
		node tools/genapi.js $$R $@/$$CATEGORY/$$(basename $$REPO).md "$$TITLE" >> $@/$$CATEGORY/index.md; \
	done


sidebar.html: api/core
	@node tools/gensidebar.js > $@

clean:
	rm -rf $(LIBS) $(LIBSINDEX)
