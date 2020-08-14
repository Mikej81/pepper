.PHONY: oss plus interactive

export CONTAINER_IMAGE=pepper
export UPSTREAM_SERVER=example.com
export PLATFORM=plus

oss:
		docker build --pull --rm -f "dockerfile" -t ${CONTAINER_IMAGE}:latest  "." --build-arg PLATFORM=oss
plus:
		docker build --pull --rm -f "dockerfile" -t ${CONTAINER_IMAGE}:latest "." --build-arg PLATFORM=plus
interactive:
		docker run --rm -it -p 80:80/tcp -p 443:443/tcp --env UPSTREAM_SERVER=${UPSTREAM_SERVER} --env PLATFORM=${PLATFORM} ${CONTAINER_IMAGE}:latest