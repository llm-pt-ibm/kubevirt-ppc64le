/* Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Copyright the KubeVirt Authors.
 *
 */

package arch

import (
v1 "kubevirt.io/api/core/v1"
)

// Ensure that there is a compile error should the struct not implement the Converter interface anymore.
var _ = Converter(&converterPPC64LE{})

type converterPPC64LE struct{}

func (converterPPC64LE) GetArchitecture() string {
return "ppc64le"
}

func (converterPPC64LE) SCSIControllerModel(_ string) string {
return "virtio-scsi"
}

func (converterPPC64LE) IsUSBNeeded(_ *v1.VirtualMachineInstance) bool {
return false
}

func (converterPPC64LE) SupportCPUHotplug() bool {
return false
}

func (converterPPC64LE) IsSMBiosNeeded() bool {
return false
}

func (converterPPC64LE) TransitionalModelType(useVirtioTransitional bool) string {
return defaultTransitionalModelType(useVirtioTransitional)
}

func (converterPPC64LE) IsROMTuningSupported() bool {
return false
}

func (converterPPC64LE) RequiresMPXCPUValidation() bool {
// MPX is x86-only
return false
}

func (converterPPC64LE) ShouldVerboseLogsBeEnabled() bool {
return false
}

func (converterPPC64LE) HasVMPort() bool {
return false
}

func (converterPPC64LE) SupportPCIHole64Disabling() bool {
return false
}

func (converterPPC64LE) SupportPCIePlacement() bool {
return false
}
