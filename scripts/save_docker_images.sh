#!/bin/bash
mkdir -p ~/estuary/docker_images
cd ~/estuary/docker_images

save_images=(\
             "njdocker1.nj.thundersoft.com/public/jenkins" \
                 "njdocker1.nj.thundersoft.com/kernelci/fileserver" \
                 "njdocker1.nj.thundersoft.com/kernelci/lava" \
                 "njdocker1.nj.thundersoft.com/kernelci/estuary-build" \
                 "debian" \
                 "openestuary/ubuntu" \
    )

for image in ${save_images[@]};do
    docker save ${image} > ${image//\//-}.tar
done
