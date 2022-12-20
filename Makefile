.SILENT:
SHELL := /bin/bash
VERSION_TAG = ${RELEASE_VERSION}
PWD = $(shell pwd)
PROTO_DIRS = $(shell find * -type f ! -empty -iname '*.proto' | xargs dirname | sort | uniq)
IMAGE_NAME = uchinx/protoc-gen
CONTAINER_NAME = uchinx_protoc_gen
DOCKER_RUN = docker exec ${CONTAINER_NAME}
DOCKER_PWD = $(DOCKER_RUN) pwd

GOLANG_REPO = uchin-mentorship/ecommerce-go
CSHARP_REPO = uchin-mentorship/ecommerce-csharp

OUTPUT_GO = out/go
OUTPUT_CSHARP = out/csharp

all: docker-start gen-go gen-csharp exit

docker-build: ; \
	if [ -z "$(shell docker images -q ${IMAGE_NAME} 2> /dev/null)" ]; then \
		echo "build docker image..." ; \
		docker build . -t ${IMAGE_NAME} ; \
	fi

docker-start: docker-build docker-stop
	@echo "initializing...";
	@docker run -d -i -v ${PWD}:/protobuf -w /protobuf --name=$(CONTAINER_NAME) --rm --init $(IMAGE_NAME)
	@echo "done preparation"

docker-stop: ; \
	if [ -n "$(shell docker ps -a | grep ${CONTAINER_NAME} 2> /dev/null)" ]; then \
		docker stop $(CONTAINER_NAME); \
	fi

exit: ; \
if [ -n "$(shell docker ps -a | grep ${CONTAINER_NAME} 2> /dev/null)" ]; then \
	docker stop $(CONTAINER_NAME); \
fi ; \
echo "generate protoc buffers successfully"

gen-go: docker-start
	@echo "gen golang"
	$(DOCKER_RUN) mkdir -p ${OUTPUT_GO}
	@for dir in $(PROTO_DIRS); do \
		files=`find $${dir} -maxdepth 1 -type f -name '*.proto'` ; \
		if [ "$${dir}" != "google/api" ] ; then \
			$(DOCKER_RUN) protoc -I . --grpc-gateway_out=${OUTPUT_GO} --grpc-gateway_opt=logtostderr=true --grpc-gateway_opt=paths=source_relative --go_out=${OUTPUT_GO} --go_opt=paths=source_relative --go-grpc_out=${OUTPUT_GO} --go-grpc_opt=paths=source_relative $$files ; \
		fi ; \
	done

gen-csharp: docker-start
	@echo "gen csharp"
	$(DOCKER_RUN) mkdir -p ${OUTPUT_CSHARP}
	@for dir in $(PROTO_DIRS); do \
		files=`find $${dir} -maxdepth 1 -type f -name '*.proto'` ; \
		$(DOCKER_RUN) mkdir -p ${OUTPUT_CSHARP}/$${dir} ; \
		$(DOCKER_RUN) protoc --csharp_out=$(OUTPUT_CSHARP)/$${dir} $$files ; \
	done

clone-go:
	$(call git_clone,${GOLANG_REPO},${OUTPUT_GO})

commit-go: ; \
	echo "commit " ${VERSION_TAG} ; \
	if [ -n "${VERSION_TAG}" ]; then \
		$(call git_commit,${OUTPUT_GO},${VERSION_TAG}) ; \
	else \
		echo "Nothing to commit" ; \
	fi ; \

release-go: clone-go gen-go commit-go

clone-csharp:
	$(call git_clone,${CSHARP_REPO},${OUTPUT_CSHARP})

commit-csharp: ; \
	echo "commit " $VERSION_TAG ; \
	if [ -n "$VERSION_TAG" ]; then \
		$(call git_commit,${OUTPUT_CSHARP},${VERSION_TAG}) ; \
	else \
		echo "Nothing to commit" ; \
	fi ; \

release-csharp: clone-csharp gen-csharp commit-csharp

release: release-go release-csharp exit

define git_clone
	mkdir -p $(2) ; \
	pushd $(2) ; \
	git clone https://github.com/$(1).git . || true ; \
	popd > /dev/null
endef

define git_commit
	pushd $(1) ; \
	git add . ; \
	git commit -m "chg(ci): update protoc buffers for $(2) version" || true ; \
	git push ; \
	popd > /dev/null
endef
