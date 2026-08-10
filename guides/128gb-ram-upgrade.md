# DS3622xs+ 128 GB RAM upgrade and hidden-DIMM access

[← Repository guide index](../README.md) · [Unsupported drives and NVMe cache](../README.md#unsupported-drives--m2-read-write-cache) · [E10M20-T1 cooling](e10m20-t1-cooling.md)

This guide documents the exact configuration and motherboard-access sequence that
worked on one Synology DS3622xs+. It covers the two factory DIMMs hidden beside the
CPU, the two normally accessible expansion slots, and validation with Synology's
memory test.

> [!WARNING]
> This is an unofficial, invasive hardware modification. Synology documents only
> the two accessible expansion slots and a lower supported maximum. Reaching the
> factory DIMMs requires moving the motherboard assembly away from the SATA
> backplane. It may affect warranty or support, and a mistake can damage the NAS or
> your data. Back up first and proceed at your own risk.

## Result at a glance

| Physical location | Memory installed | Capacity | Result |
|---|---|---:|---|
| Hidden internal/factory slots | **2×32 GB OWC ECC SODIMM** | 64 GB | Boots |
| Accessible expansion slots | **2×32 GB Kingston Server Premier KSM32SED8/32HC ECC SODIMM** | 64 GB | Boots |
| **Total** | **4×32 GB ECC SODIMM** | **128 GB** | **Detected by DSM; memory test passed** |

The complete Synology memory test with 128 GB installed took approximately
**20 hours** on this machine and completed successfully.

## The important trap

The two slots visible through the normal side access are **expansion slots**. They
are not the slots containing the factory 2×8 GB modules.

The first attempt placed the OWC 2×32 GB kit in those accessible slots while the
factory 2×8 GB remained installed. The result was:

- fans running;
- continuously blinking blue power LED;
- no successful boot.

After the OWC modules replaced the hidden factory modules beside the CPU, the NAS
booted with 64 GB. Adding the two Kingston modules to the accessible expansion
slots then produced the working 128 GB configuration.

| Configuration tried | Result |
|---|---|
| Factory internal 2×8 GB | Normal factory boot |
| Factory internal 2×8 GB + OWC 2×32 GB in accessible slots | **No boot; blinking blue LED** |
| OWC 2×32 GB replacing the factory internal modules | **Boots; 64 GB** |
| OWC 2×32 GB internal + Kingston KSM32SED8/32HC 2×32 GB accessible | **Boots; 128 GB; memory test passed** |

## Before opening the NAS

1. Confirm that the storage pool is healthy and no rebuild, scrub, expansion, or
   cache operation is running.
2. Make a current backup of important data.
3. Shut the NAS down normally. Disconnect power, network, expansion-unit, USB,
   and other cables.
4. Let the unit and any NVMe SSDs cool.
5. Number every drive tray so each drive can be returned to the same bay.
6. Photograph the rear panels, bottom screws, cable routing, and every connector
   before removing anything.
7. Use ESD precautions and keep screws grouped by location.

This is not a generic teardown. Chassis revisions and installed cards can differ.
If the assembly does not move after the described fasteners are removed, stop and
find the remaining restraint rather than applying force.

## Exact motherboard-access sequence

### 1. Remove and order all drives

Remove every drive tray. Mark each tray by bay number and keep the drives in their
original order. Do not rely on memory when reinstalling a populated 12-bay NAS.

### 2. Remove the top and side panels

Remove the fasteners for the external top and side chassis panels, then slide the
panels off. This exposes the PCIe area, accessible expansion DIMMs, motherboard
assembly, rear I/O area, and SATA backplane relationship.

### 3. Remove the PCIe expansion card

If an E10M20-T1 or another PCIe card is installed, release its retention hardware
and remove the card before moving the motherboard. Store it safely.

### 4. Free the motherboard rear-I/O panel

At the rear of the NAS, the **fan panel/frame** and the **motherboard rear-I/O
panel** are separate structures. The motherboard I/O panel is the section carrying
the LAN, USB, management, and other motherboard ports.

Remove the screws that join the outer rear chassis panel to this motherboard I/O
section. These fasteners must be released so the motherboard assembly can move.

> [!CAUTION]
> **Do not remove the fan-panel screws or fan-retention hardware.** The rear fan
> panel does not need to be removed for this procedure. It is an easy red herring.

### 5. Remove the large motherboard screws underneath

With the empty NAS safely positioned so the underside is accessible, remove the
large bottom screws that retain the motherboard assembly/carrier.

This is the step missing from the normal RAM instructions. Until these screws and
the relevant rear-I/O screws are removed, the motherboard cannot move far enough
to disengage from the SATA backplane.

### 6. Decide how to handle the motherboard cables

The safer approach is to photograph, label, and disconnect the power, fan/control,
and other cables that prevent the motherboard from moving without strain.

On the documented machine, the cables were left connected and the motherboard was
moved only far enough to replace the DIMMs. That worked, but it leaves very little
margin for error.

> [!WARNING]
> If you leave cables connected, support the assembly and watch every cable while
> it moves. Never let a cable carry the motherboard's weight, pull on wires instead
> of connector bodies, or stretch a connector. Disconnect any cable that becomes
> taut. The fact that this shortcut worked once does not make it the safest method.

### 7. Disengage the motherboard from the SATA backplane

Move the motherboard assembly **downward/away from the drive backplane**, evenly
and only as far as necessary. The motherboard connects directly to the 12-bay SATA
backplane and must slide out of that connection before the hidden DIMMs are
accessible.

Watch the motherboard-to-backplane connection as it separates. Do not twist the
board, pry the connector, or force the carrier. If it does not move, re-check the
rear and bottom fasteners and cable restraints.

### 8. Access and remove the factory DIMMs

Once the motherboard is displaced far enough, the two factory SODIMM slots beside
the CPU become accessible. Release the retaining clips and remove the factory
2×8 GB modules.

Handle memory only by its edges. Avoid touching contacts or nearby components.

### 9. Install the OWC internal memory

Install **2×32 GB OWC ECC SODIMM** in the two hidden/internal slots. Ensure each
module is fully inserted at the correct angle and both retaining clips lock.

### 10. Reconnect the motherboard and SATA backplane

Align the motherboard connector carefully with the SATA backplane, then move the
assembly evenly into its normal position until the connection is fully seated.

> [!CAUTION]
> Do **not** use the chassis screws to pull a misaligned connector together. Seat
> the motherboard/backplane connection correctly first; reinstall screws only
> after the assembly is flush and aligned.

### 11. Reinstall the bottom and rear-I/O fasteners

Reinstall the large motherboard-retaining screws underneath the NAS and the rear
screws securing the motherboard I/O section. Do not add or remove fan-panel
hardware as part of this step.

Reconnect any motherboard cables that were removed. Compare every connector and
cable route with the photos taken before disassembly.

### 12. Reinstall the PCIe card

Insert the E10M20-T1 or other PCIe card squarely, confirm it is fully seated, and
secure its retention hardware. If using the cooling modification documented in
this repository, see [E10M20-T1 NVMe cooling](e10m20-t1-cooling.md) before closing
the chassis.

### 13. Install the expansion memory

Install **2×32 GB Kingston Server Premier KSM32SED8/32HC ECC SODIMM** in the two
normally accessible expansion slots. Confirm both modules and retaining clips are
fully seated.

For easier fault isolation, you can follow the sequence used on the documented
machine: first reassemble and verify a successful 64 GB boot with only the OWC
internal pair, shut down normally, then add the Kingston pair to the accessible
slots and verify the 128 GB boot. This takes longer but separates an internal-DIMM
or motherboard-connection problem from an expansion-DIMM problem.

### 14. Reassemble and return drives to their bays

Reinstall the top and side panels. Return every numbered drive to its original bay.
Reconnect the cables and power on the NAS.

## First-boot checks

The first boot after a memory change may take longer than usual. Do not interrupt
it immediately. After DSM becomes available:

1. Open **DSM → Control Panel → Info Center** and confirm that all **128 GB** are
   reported.
2. Open Storage Manager and confirm that the storage pool, volume, drives, cache,
   and PCIe/NVMe devices are healthy.
3. Check system logs for memory, PCIe, fan, drive, or unexpected-shutdown errors.
4. If the power LED keeps blinking and the NAS never boots, shut down and re-check
   module location, seating, and motherboard/backplane/cable connections. Do not
   repeatedly power-cycle a partially connected machine.

## Run the Synology memory test

Booting and displaying 128 GB is not sufficient validation. Synology provides a
memory test through Synology Assistant:

1. Install and open **Synology Assistant** on a computer on the same network.
2. Open its preferences/settings and enable **Memory Test**.
3. Ensure at least one built-in LAN port on the NAS is connected and the NAS status
   is **Ready**.
4. Select the NAS and choose **Memory Test**.
5. Follow the wizard. The NAS will reboot and be unavailable while the test runs.
6. Keep Synology Assistant open; it displays `Performing memory test (x%)`.
7. When the NAS returns to **Ready**, confirm that no memory-test error was shown
   and check the system log.

On this 128 GB configuration, one complete test took approximately **20 hours**
and passed. Plan for substantial downtime; the duration may differ on another unit.
Synology recommends repeated tests when diagnosing memory problems.

Official reference: [How and when should I run a memory test on my Synology NAS?](https://kb.synology.com/en-uk/DSM/tutorial/How_can_I_run_a_memory_test_on_my_Synology_NAS)

## Recommended photo sequence

Photos will make the unusual steps much clearer. A useful set is:

1. numbered drive trays;
2. top and side panels removed;
3. rear view marking **remove** versus **do not remove** screws;
4. PCIe card removed;
5. large motherboard screws underneath;
6. motherboard-to-SATA-backplane connection;
7. cables before any disconnection;
8. motherboard displaced just enough to expose the hidden DIMMs;
9. factory modules removed and OWC modules installed;
10. DSM reporting 128 GB and the successful test result.

## Limits of this result

- This proves one mixed OWC/Kingston configuration on one DS3622xs+; it is not a
  compatibility guarantee for every module revision or chassis revision.
- It exceeds Synology's documented memory configuration and uses non-Synology
  memory. Synology may require the supported configuration for service.
- A passed test improves confidence but cannot guarantee future stability.
- Preserve the factory DIMMs so the supported configuration can be restored for
  troubleshooting.

Synology's official hardware guide documents only the accessible expansion slots:
[DS3622xs+ Hardware Installation Guide (PDF)](https://global.download.synology.com/download/Document/Hardware/HIG/DiskStation/22-year/DS3622xs%2B/enu/Syno_HIG_DS3622xs%2B_enu.pdf).

---

[← Back to the repository guide index](../README.md)
