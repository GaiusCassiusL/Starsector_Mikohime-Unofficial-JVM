# Third-party notices

## OpenJDK

This project builds and modifies the OpenJDK `jdk-28+13` source at commit
`fd9698357bb034c527c9ccdd6888a2abd75c0043`. OpenJDK source files retain their
upstream copyright and license notices. The upstream source includes the GNU
General Public License, version 2 (GPL-2.0), and applies the Classpath
Exception only to files whose notices designate it. Other components may
carry separate licenses; their notices are retained in the JDK image's
`legal/` directory and in the corresponding source.

The project patch changes OpenJDK source files. Those changes are governed by
the license terms applicable to each upstream file, not by this repository's
MIT license. The complete corresponding source for each build is distributed
as `jdk-28+13Miko-source.tar.gz`; it contains the modified OpenJDK source,
the patch, and the project build materials.

License references:

- [OpenJDK GPLv2 with Classpath Exception](https://openjdk.org/legal/gplv2+ce.html)
- [OpenJDK legal and licensing information](https://openjdk.org/legal/)
- [OpenJDK trademark notice](https://openjdk.org/legal/openjdk-trademark-notice.html)
- [OpenJDK jdk-28+13 source](https://github.com/openjdk/jdk/tree/jdk-28%2B13)

## Build-only tools

The build instructions use a boot JDK, JDK 17 to build jtreg, and jtreg. These
are build prerequisites and are not included in the custom JDK release
archives. They remain subject to their own licenses when obtained or
redistributed.

## Trademarks

Java and OpenJDK are trademarks or registered trademarks of Oracle and/or its
affiliates. This project is unofficial and is not endorsed by Oracle or the
OpenJDK project.
