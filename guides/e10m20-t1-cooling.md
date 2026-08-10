# DS3622xs+ E10M20-T1 NVMe cooling

[← Repository guide index](../README.md) · [128 GB RAM upgrade](128gb-ram-upgrade.md) · [Unsupported drives and NVMe cache](../README.md#unsupported-drives--m2-read-write-cache)

This guide documents the active-airflow modification used for a Synology
E10M20-T1 carrying two enterprise NVMe SSDs in a DS3622xs+.

## Tested hardware

| Component | Hardware |
|---|---|
| NAS | Synology DS3622xs+ |
| PCIe card | Synology E10M20-T1 with integrated 10GbE |
| NVMe SSDs | **2× Samsung PM983 3.84 TB M.2 NVMe** |
| SSD model | **MZ-1LB3T80** |
| Additional fan | **Noctua NF-A12x15 FLX** |
| Fan size | **120 × 120 × 15 mm** slim profile |
| Fan connection | **3-pin, 12 V** |

## Why add a fan?

During normal NAS use, the two PM983 SSDs operated acceptably. Sustained
benchmarks exposed a different problem: the SSDs became hot enough that the
benchmark could eventually fail from overheating.

The E10M20-T1 includes heatsinks, but heatsinks still need airflow. The slim
Noctua fan was positioned to move air directly across the E10M20-T1 heatsinks and
both PM983 SSDs. After the modification, sustained high-load benchmarks behaved
much better and the overheating-related failures were no longer observed.

This modification is **not required** for the 128 GB RAM upgrade or for the
third-party-drive scripts. It addresses a separate thermal issue that appears
under sustained NVMe load.

> [!WARNING]
> This is an unofficial chassis modification. Incorrect mounting can short a
> component, block the NAS airflow path, foul a fan blade, overload a power source,
> or allow a loose fan to damage the card. Shut down and disconnect the NAS before
> working inside it. Use ESD precautions and proceed at your own risk.

## Installation principles

The exact position is best documented with a photo because clearances depend on
the installed PCIe card, cables, and chassis. The working installation followed
these principles:

1. **Direct the airflow across the E10M20-T1 heatsinks.** The purpose is airflow
   over both NVMe locations, not simply more air somewhere inside the chassis.
2. **Preserve the NAS airflow path.** Avoid placing the fan so it fights the rear
   chassis fans or creates a dead zone around the CPU, memory, or drives.
3. **Keep safe clearance.** Check both faces of the fan, the blades, the E10M20-T1,
   memory, motherboard, chassis panels, and every cable before closing the NAS.
4. **Mount it securely and non-conductively.** The fan must not move during
   transport or vibration, and no fastener should contact PCB traces or components.
5. **Route the cable away from blades and hot components.** Secure enough slack for
   servicing, but do not leave a loop that can enter a fan.
6. **Use a suitable fan power source.** The NF-A12x15 FLX is a 3-pin, 12 V fan.
   Do not connect it to an unidentified header or assume every internal connector
   has the correct voltage/current capacity. Follow the fan and power-source
   specifications for the actual installation.
7. **Test with the chassis open, then closed.** Verify that the added fan starts
   reliably, does not rub, and does not trigger fan or power warnings before
   returning the NAS to service.

Because the exact mounting hardware and power source have not been recorded in
this guide, do not infer them from the fan model alone. Add the installation photo
and those two details before another person attempts to copy the physical setup.

## Suggested procedure

1. Stop storage benchmarks and confirm that no storage-pool, cache, scrub, or
   rebuild operation is running.
2. Record the current idle and sustained-load temperature of both NVMe SSDs.
3. Shut the NAS down normally and disconnect all cables.
4. Remove the relevant chassis panel using the normal DS3622xs+ access procedure.
5. Inspect the E10M20-T1, its heatsinks, nearby cables, and available fan clearance.
6. Position the Noctua NF-A12x15 FLX so its airflow crosses both M.2 heatsinks.
7. Secure the fan, connect it only to a verified suitable power source, and secure
   its cable away from all fan blades.
8. Before closing the chassis, power on briefly and confirm correct fan operation,
   airflow direction, and clearance. Shut down again before making adjustments.
9. Reassemble the NAS and confirm that the E10M20-T1, 10GbE interface, both NVMe
   SSDs, storage pool, and cache appear normally.
10. Repeat the same sustained workload used for the baseline while watching both
    SSD temperatures and system logs.

## Monitoring and validation

On DSM, query each NVMe with Synology's tool:

```sh
sudo synonvme --smart-info-get /dev/nvme0n1
sudo synonvme --smart-info-get /dev/nvme1n1
```

Depending on what is installed, `nvme smart-log` may also be available. DSM's old
bundled `smartctl` can fail against newer NVMe with `NVMe Status 0x4002`; that does
not by itself prove the SSD is unhealthy.

Validate more than the temperature shown at idle:

- record both SSD temperatures before the benchmark;
- use the same benchmark duration and workload for before/after comparison;
- watch for throttling, benchmark errors, I/O errors, controller resets, and
  critical-temperature events;
- verify the SSD cache after testing;
- check that CPU, HDD, and system temperatures did not worsen because the new fan
  altered the chassis airflow.

For the documented machine, the useful result was practical rather than a claimed
universal temperature delta: sustained benchmarks stopped failing from the
overheating behavior seen before the fan was added.

## Relationship to the unsupported-drive guide

The E10M20-T1 and PM983 SSDs are also used by the repository's
[third-party NVMe read-write-cache procedure](../README.md#unsupported-drives--m2-read-write-cache).
Cooling does not whitelist the SSDs or unlock DSM's cache-creation path; use the
drive/cache guide for that. Conversely, the whitelist does not solve inadequate
airflow under sustained load.

If you temporarily remove or recreate the SSD cache while changing the hardware,
follow the removal and recreation sequence in the root guide. Do not pull a cached
SSD or card from a running system.

## Photo checklist

A final photo set should show:

1. the E10M20-T1 and both PM983 SSD locations;
2. the Noctua model label;
3. the fan's position and airflow direction;
4. the mounting points;
5. cable routing and the actual power connection;
6. clearance with the chassis panel installed.

## Limits of this result

- The result is specific to an E10M20-T1 with two Samsung PM983 3.84 TB
  `MZ-1LB3T80` SSDs and the described fan.
- Workload, ambient temperature, dust, fan mode, heatsink contact, and chassis
  placement all affect temperatures.
- A benchmark no longer failing is useful evidence, but long-term temperature and
  error monitoring are still required.

---

[← Back to the repository guide index](../README.md)
