package webhooks

import (
metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
k8sfield "k8s.io/apimachinery/pkg/util/validation/field"

v1 "kubevirt.io/api/core/v1"
)

func ValidateVirtualMachineInstancePpc64leSetting(field *k8sfield.Path, spec *v1.VirtualMachineInstanceSpec) []metav1.StatusCause {
var statusCauses []metav1.StatusCause
return statusCauses
}
