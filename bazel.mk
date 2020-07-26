.BAZELISK         := ./tools/bazelisk
.UNAME_S          := $(shell uname -s)
.BAZELISK_VERSION := 1.5.0

ifeq ($(.UNAME_S),Linux)
	.BAZELISK = ./tools/bazelisk-linux-amd64
endif
ifeq ($(.UNAME_S),Darwin)
	.BAZELISK = ./tools/bazelisk-darwin-amd64
endif

PREFIX                = ${HOME}
BAZEL_OUTPUT          = --output_base=${PREFIX}/bazel/output
BAZEL_REPOSITORY      = --repository_cache=${PREFIX}/bazel/repository_cache
BAZEL_FLAGS           = --experimental_remote_download_outputs=minimal --experimental_inmemory_jdeps_files --experimental_inmemory_dotd_files

BAZEL_BUILDKITE       = --flaky_test_attempts=3 --build_tests_only --local_test_jobs=12 --show_progress_rate_limit=5 --curses=yes --color=yes --terminal_columns=143 --show_timestamps --verbose_failures --keep_going --jobs=32 --announce_rc --experimental_multi_threaded_digest --experimental_repository_cache_hardlinks --disk_cache= --sandbox_tmpfs_path=/tmp --experimental_build_event_json_file_path_conversion=false --build_event_json_file=/tmp/test_bep.json --disk_cache=${PREFIX}/bazel/cas --test_output=errors
BAZEL_BUILDKITE_BUILD = --show_progress_rate_limit=5 --curses=yes --color=yes --terminal_columns=143 --show_timestamps --verbose_failures --keep_going --jobs=32 --announce_rc --experimental_multi_threaded_digest --experimental_repository_cache_hardlinks --disk_cache= --sandbox_tmpfs_path=/tmp --disk_cache=${PREFIX}/bazel/cas
BAZEL_REMOTE          = --remote_cache=http://localhost:8080
LINUX                 = --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64
INCOMPATIBLE          = --incompatible_no_rule_outputs_param=false

# Put all flags together
.BAZEL      = $(.BAZELISK) $(BAZEL_OUTPUT)

BUILD_FLAGS = $(BAZEL_REPOSITORY) $(BAZEL_FLAGS) $(BAZEL_REMOTE) $(BAZEL_BUILDKITE_BUILD)
TEST_FLAGS  = $(BAZEL_REPOSITORY) $(BAZEL_FLAGS) $(BAZEL_REMOTE) $(BAZEL_BUILDKITE)

version: ## Prints the bazel version
	@$(.BAZELISK) version
	@make separator

separator:
	@echo "-----------------------------------"

build: ## Build binaries
	@make version
	@$(.BAZEL) build $(BUILD_FLAGS) //cmd/server:server

docker: ## Build docker images
	@make version
	@$(.BAZEL) build $(BUILD_FLAGS) $(LINUX)  //cmd/server:docker

test: ## Test
	@make version
	@$(.BAZEL) build $(TEST_FLAGS) //pkg/...

gen: # Generate BUILD.bazel files
	@make version
	@$(.BAZEL) run //:gazelle -- update -exclude=protos

deps: # Add dependencies based on go.mod
	@$(.BAZEL) run $(BUILD_FLAGS) //:gazelle -- update-repos -from_file=go.mod -to_macro=repositories.bzl%go_repositories

clean:
	$(.BAZEL) clean $(BUILD_FLAGS) --expunge

ifndef WORKSPACE
define WORKSPACE
load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "8663604808d2738dc615a2c3eb70eba54a9a982089dd09f6ffe5d0e75771bc4f",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.23.6/rules_go-v0.23.6.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.23.6/rules_go-v0.23.6.tar.gz",
    ],
)

load(
    "@io_bazel_rules_go//go:deps.bzl",
    "go_rules_dependencies",
    "go_register_toolchains",
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "cdb02a887a7187ea4d5a27452311a75ed8637379a1287d8eeb952138ea485f7d",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.1/bazel-gazelle-v0.21.1.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.1/bazel-gazelle-v0.21.1.tar.gz",
    ],
)

load(
    "@bazel_gazelle//:deps.bzl",
    "gazelle_dependencies",
    "go_repository",
)

go_rules_dependencies()

go_register_toolchains()

gazelle_dependencies()

http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "4521794f0fba2e20f3bf15846ab5e01d5332e587e9ce81629c7f96c793bb7036",
    strip_prefix = "rules_docker-0.14.4",
    urls = ["https://github.com/bazelbuild/rules_docker/releases/download/v0.14.4/rules_docker-v0.14.4.tar.gz"],
)

load(
    "@io_bazel_rules_docker//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

http_archive(
    name = "io_bazel_rules_k8s",
    sha256 = "d91aeb17bbc619e649f8d32b65d9a8327e5404f451be196990e13f5b7e2d17bb",
    strip_prefix = "rules_k8s-0.4",
    urls = ["https://github.com/bazelbuild/rules_k8s/releases/download/v0.4/rules_k8s-v0.4.tar.gz"],
)

load("@io_bazel_rules_k8s//k8s:k8s.bzl", "k8s_repositories")
k8s_repositories()

http_archive(
    name = "com_google_protobuf",
    strip_prefix = "protobuf-3.12.3",
    urls = ["https://github.com/google/protobuf/archive/v3.12.3.zip"],
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

#load("//:repositories.bzl", "go_repositories")
#go_repositories()
endef
export WORKSPACE
endif

ifndef BUILD_BAZEL
define BUILD_BAZEL
load("@bazel_gazelle//:def.bzl", "gazelle")

gazelle(
    name = "gazelle",
    prefix = "github.com/MY_ORG/MY_REPO",
)
# gazelle:exclude protos
# gazelle:proto disable
endef
export BUILD_BAZEL
endif

ifndef BAZEL_RC
define BAZEL_RC
build --host_force_python=PY2
test --host_force_python=PY2
run --host_force_python=PY2
endef

export BAZEL_RC
endif

bazelisk: # Download bazelisk
	curl -sLo tools/bazelisk-darwin-amd64 https://github.com/bazelbuild/bazelisk/releases/download/v$(.BAZELISK_VERSION)/bazelisk-darwin-amd64
	curl -sLo tools/bazelisk-linux-amd64 https://github.com/bazelbuild/bazelisk/releases/download/v$(.BAZELISK_VERSION)/bazelisk-linux-amd64
	chmod +x ./tools/bazelisk-darwin-amd64
	chmod +x ./tools/bazelisk-linux-amd64

setup: # Setup the initial files to run bazel
	@make init

init: # Generate the initial files to run bazel
	mkdir tools
	@make bazelisk
	echo "$$WORKSPACE" > WORKSPACE
	echo "$$BUILD_BAZEL" > BUILD.bazel
	echo "$$BAZEL_RC" > .bazelrc
	@make separator
	@echo "modify this line into BUILD.bazel"
	@echo '	    prefix = "github.com/MY_ORG/MY_REPO"'
