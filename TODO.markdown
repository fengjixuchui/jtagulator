JTAGulator To Do
================

This is a list of features and/or additions we'd like to eventually build into the JTAGulator. It is by no means exhaustive and we are happy to take suggestions and/or pull requests!


Bug Fixes
---------

* Inconsistent IDCODE Scan and/or BYPASS Scan results on certain targets. Confirmed on HTC One X, Pogoplug, BeagleBone Black, and Arcadyan VGV7519. May be multiple issues or all due to a single root cause. [Issue #3](https://github.com/grandideastudio/jtagulator/issues/3) (in progress)


General
-------

* Compatibility w/ [OpenOCD](http://openocd.org): This would enable the JTAGulator to directly manipulate target devices once the interface is found (instead of having to disconnect the JTAGulator and connect other JTAG hardware to do the job like we have to do now). 


Protocols/Discovery
-------------------

* JTAG: RTCK pin detection (adaptive clocking)

* JTAG: Compact JTAG aka cJTAG (IEEE 1149.7) [Issue #13](https://github.com/grandideastudio/jtagulator/issues/13)

* UART: Automatic baud rate detection for UART Scan


Hardware
--------

* Level-shifting module: Plug-in module (to connect to 2x5 headers) for arbitrary target voltage level shifting above the native JTAGulator range (1.2V to 3.3V). Particularly useful for industrial/SCADA equipment running at 5V or greater.


Documentation
-------------

* Update the JTAGulator Product Brief (in progress)

* FAQ/Troubleshooting Guide (in progress)

* New feature review video
