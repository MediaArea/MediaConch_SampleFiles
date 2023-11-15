#!/bin/bash

workpath="$(mktemp -d -p '' groundtruth.XXXXXXXXXX)"
outpath="${PWD}"

mkdir "${workpath}/bin"
export PATH="${workpath}/bin:${PATH}"

pushd "${workpath}"
    # clone groundtruth repository
    git clone --depth=1 https://github.com/MediaArea/groundtruth.git

    # clone and build ffmpeg sources
    git clone --depth=1 git://git.ffmpeg.org/ffmpeg.git -b n5.1
    mv ffmpeg/* .
    rm -fr ffmpeg
    ./configure --disable-doc --disable-x86asm --disable-ffplay --disable-ffprobe --disable-everything --disable-autodetect \
                --enable-static --enable-indev=lavfi --enable-filter=scale,color,testsrc2,sine,aresample --enable-decoder=rawvideo,ffv1,flac,pcm_s16le \
                --enable-encoder=rawvideo,ffv1,flac,pcm_s16le --enable-demuxer=matroska --enable-muxer=matroska --enable-protocol=file
    make
    cp -f ffmpeg bin # copy vanilla ffmpeg binary to PATH

    for file in $(ls -v groundtruth/matroska/*.md) ; do
        if ! echo "${file}" | grep -Eq '^groundtruth/matroska/[0-9]+\.md$' ; then
            continue
        fi

        name="$(grep -Eom1 '^# [^[:space:]]+$' ${file} | grep -Eom1 '[^[:space:]]+$')"
        script="$(perl -0777lne 'print for grep !//,/^```sh\s+(.*?)^```/mgs' ${file})"
        policy="$(perl -0777lne 'print for grep !//,/^```xml\s+(.*?)^```/mgs' ${file})"

        if [ -z "${script}" ] ; then
            continue
        fi

        if [ -n "${policy}" ] ; then
            echo "${policy}" > "${outpath}/${name}.xml"
        fi

        echo "${script}" > "${name}.sh"
        sed -i'.bak' 's!make!make --assume-new libavcodec/ffv1enc.c --assume-new libavcodec/ffv1enc_template.c!g' "${name}.sh"
        sh "${name}.sh"
        rm "${name}.sh"

        # clean intermediate files
        rm -f "reference.xml" "reference.mkv"

        mv -i ${name}*.mkv "${outpath}"
done

rm -fr "${workpath}"
