#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7

StrConstant k2600PackageName="Keithley2336"

Constant k2600_MAX_LIMITI=1.5
Constant k2600_MIN_LIMITI=1e-11
Constant k2600_DEFAULT_LIMITI=1.5
Constant k2600_MAX_LIMITV=200
Constant k2600_MIN_LIMITV=0.001
Constant k2600_DEFAULT_LIMITV=20
StrConstant k2600_SOURCE_TYPE="Not Used;V-Source;I-Source;"
StrConstant k2600_VOLTAGE_RANGE_STR="200V;20V;2V;200mV;"
StrConstant k2600_VOLTAGE_AUTORANGE_STR="AUTO/200V;AUTO/20V;AUTO/2V;AUTO/200mV;"
StrConstant k2600_VOLTAGE_RANGE_VALUE="200;20;2;0.2;"
StrConstant k2600_CURRENT_RANGE_STR="1.5A;1A;100mA;10mA;1mA;100uA;10uA;1uA;100nA;10nA;1nA;100pA;"
StrConstant k2600_CURRENT_AUTORANGE_STR="AUTO/1.5A;AUTO/1A;AUTO/100mA;AUTO/10mA;AUTO/1mA;AUTO/100uA;AUTO/10uA;AUTO/1uA;AUTO/100nA;AUTO/10nA;AUTO/1nA;AUTO/100pA;"
StrConstant k2600_CURRENT_RANGE_VALUE="1.5;1;0.1;0.01;0.001;1e-4;1e-5;1e-6;1e-7;1e-8;1e-9;1e-10;"
StrConstant k2600_SENSE_TYPE="Two wire;Four wire"
StrConstant k2600_AUTOZERO_TYPE="Enabled (auto);Only once;Disabled"
StrConstant k2600_SINK_MODE="Disabled;Enabled"
StrConstant k2600_SMUConditionStrPrefix="SMUCondition_Chan"
StrConstant k2600_SMURTUpdateStrPrefix="SMURTUpdate_Chan"

StrConstant k2600_FILTER_TYPE="Disabled;Median;Moving Average;Repeat Average"
StrConstant k2600_initscriptNamePrefix="IgorKeithleyInit_"

