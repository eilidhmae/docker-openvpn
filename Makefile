.PHONY: test

build:
	docker build -t eilidhmae/openvpn .

test: build
	test/run.sh eilidhmae/openvpn

clean:
	docker volume rm basic-data basic-data-otp dual-data ovpn-revoke-test-data

distclean:
	docker rm -af
	docker volume rm -af
	docker images |awk '/librarytest/{print "docker image rm "$$3}' |sh
	docker images |awk '/none/{print "docker image rm "$$3}' |sh

latest:
	docker push eilidhmae/openvpn:latest docker.io/eilidhmae/openvpn:latest

release:
	docker tag eilidhmae/openvpn:latest eilidhmae/openvpn:release
	docker push eilidhmae/openvpn:release docker.io/eilidhmae/openvpn:release
