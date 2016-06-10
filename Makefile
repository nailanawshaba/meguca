GULP="./node_modules/.bin/gulp"

ifeq ($(OS), Windows_NT)
	BUILD_PATH="/.meguca_build/src/github.com/bakape"
	export GOPATH="/.meguca_build"
	export PKG_CONFIG_PATH:=$(PKG_CONFIG_PATH):/mingw64/lib/pkgconfig/
	export PKG_CONFIG_LIBDIR=/mingw64/lib/pkgconfig/
	export PATH:=$(PATH):/mingw64/bin/
	BINARY=meguca.exe
	ISWINDOWS=true
else
	BUILD_PATH="./.build/src/github.com/bakape"
	export GOPATH=$(shell pwd)/.build
	BINARY=meguca
	ISWINDOWS=false
endif

.PHONY: server client init

all: server client init

client:
	npm update
	$(GULP)
	$(GULP) es5

watch:
	$(GULP) -w

server: server_deps
	go build -v -o $(BINARY)
ifeq ($(ISWINDOWS), true)
	cp /mingw64/bin/*.dll ./
endif

server_deps: build_dirs
	go list -f '{{.Deps}}' . \
		| tr "[" " " \
		| tr "]" " " \
		| xargs go list -e -f '{{if not .Standard}}{{.ImportPath}}{{end}}' \
		| grep -v 'github.com/bakape/meguca' \
		| xargs go get -v

build_dirs:
ifeq ($(ISWINDOWS), true)
	rm -rf $(BUILD_PATH)
endif
	mkdir -p $(BUILD_PATH)
	ln -sfn "$(shell pwd)" $(BUILD_PATH)/meguca

clean: client_clean
	rm -rf .build .ffmpeg node_modules $(BINARY)
ifeq ($(ISWINDOWS), true)
	rm -rf /.meguca_build *.dll
endif

client_clean:
	rm -rf www/js www/css/*.css www/css/maps www/lang

dist_clean: clean
	rm -rf img config/config.json assets error.log .package

init:
	mkdir -p assets img/{src,thumb,mid}
	cp -n config/defaults.json config/config.json

test: server_deps
	go get gopkg.in/check.v1
	go test ./...

install_deps_deb:
	apt-get update
	apt-get install -y libvpx-dev libmp3lame-dev libopus-dev libvorbis-dev \
		libx264-dev libtheora-dev git build-essential yasm

build_ffmpeg:
	git clone --depth 1 -b release/3.0 git://source.ffmpeg.org/ffmpeg.git \
		.ffmpeg
	cd .ffmpeg; \
	./configure --enable-libmp3lame --enable-libx264 --enable-libvpx \
		--enable-libvorbis --enable-libopus --enable-libtheora --enable-gpl
	$(MAKE) -C .ffmpeg

install_ffmpeg:
	$(MAKE) -C .ffmpeg install

package_win64: all
	rm -rf .package
	mkdir -p .package/{config,templates} .package/img/{src,thum,mid}
	cp -r docs scripts www *.dll CHANGELOG.md README.md LICENSE $(BINARY) \
		.package/
	cp config/defaults.json .package/config/
	cp config/defaults.json .package/config/config.json
	cp -r templates/*.html .package/templates/
	cd .package; zip -r meguca_win64.zip .
