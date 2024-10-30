# This dockerfile is intended to allow you to test changes to
# dnf_wrapper_test.sh. It will create a simple ubi9 based image with the
# dnf_wrapper.sh wrapped around dnf/yum.
# Build the container image:
#   1. Authenticate with app.ci
#   2. oc registry login
#   3. ocp-build-data$ podman build -f ci_images/dnf_wrapper_test.Dockerfile .
# With the resulting image, test with AND without app.ci connectivity

# Testing WITHOUT connectivity to app.ci (emulate a developer running a "podman build" with an upstream CI Dockerfile).
# 1. Connect to the Red Hat VPN.
# 2. podman run --network=host -e CI_RPM_SVC=base-4-17-rhel9 --rm <built-image-id> dnf search vim
# You should see the wrapper fail to download repo definitions from the RPM mirror service and fallback to installing
# VPN repos. If you are connected to the VPN, you should see a repo "rhel-9-baseos-rpms-x86_64" successfully return
# RPM information for DNF to analyze.

# Testing WITH connectivity to app.ci (emulate behavior of CI pod build).
# 1. Authenticate with app.ci
# 2. Run "oc proxy &" to create a proxy connection to app.ci's kube API.
# 3. podman run --network=host -e CI_RPM_SVC=http://localhost:8001/api/v1/namespaces/ocp/services/base-4-17-rhel9:80/proxy/ --rm <built-image-id> dnf search vim
# You should see a successful attempt to install CI repository data but UNSUCCESSFUL attempts to download repo data:
# e.g. "Status code: 400 for http://api.ci.l2s4.p1.openshiftapps.com:6443/rhel-9-openstack-17-rpms/repodata/repomd.xml"
# This is just a side effect of using "oc proxy" instead of being an actual pod in the cluster.

FROM registry.ci.openshift.org/ocp/4.17:base-rhel9

# Used by dnf_wrapper.sh and upstream component CI build scripts to detect whether they are running in the context
# of OpenShift CI pod or elsewhere (e.g. brew).
ENV OPENSHIFT_CI="true"

# Ensure that repo files can be written by non-root users at runtime so that repos
# can be resolved on build farms and written into yum.repos.d.
RUN chmod 777 /etc/yum.repos.d/

# Install the dnf/yum wrapper that will work for CI workloads.
ENV DNF_WRAPPER_DIR=/bin/dnf_wrapper
ADD ci_images/dnf_wrapper.sh /tmp
ADD ci_images/install_dnf_wrapper.sh /tmp
RUN chmod +x /tmp/*.sh && \
    /tmp/install_dnf_wrapper.sh
# Ensure dnf wrapper scripts appear before anything else in the $PATH
ENV PATH=$DNF_WRAPPER_DIR:$PATH

# Add example doozer repos so that someone connected to the VPN can use those
# repositories. The dnf_wrapper will enable these repos if it detects
# it is not running on a build farm.
RUN echo -e '\
[rhel-9-baseos-rpms-x86_64] \n\
name = rhel-9-baseos-rpms-x86_64 \n\
baseurl         = https://rhsm-pulp.corp.redhat.com/content/eus/rhel9/9.2/x86_64/baseos/os/ \n\
enabled         = 1 \n\
gpgcheck        = 0 \n\
' > $DNF_WRAPPER_DIR/unsigned.repo
