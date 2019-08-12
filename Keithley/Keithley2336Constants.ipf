#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7

StrConstant K2336PackageName="Keithley2336"

Constant k2336_MAX_LIMITI=1.5
Constant k2336_MIN_LIMITI=1e-11
Constant k2336_DEFAULT_LIMITI=1.5
Constant k2336_MAX_LIMITV=200
Constant k2336_MIN_LIMITV=0.001
Constant k2336_DEFAULT_LIMITV=20
StrConstant k2336_SOURCE_TYPE="Not Used;V-Source;I-Source;"
StrConstant k2336_VOLTAGE_RANGE_STR="200V;20V;2V;200mV;"
StrConstant k2336_VOLTAGE_RANGE_VALUE="200;20;2;0.2;"
StrConstant k2336_CURRENT_RANGE_STR="1.5A;1A;100mA;10mA;1mA;100uA;10uA;1uA;100nA;10nA;1nA;100pA;"
StrConstant k2336_CURRENT_RANGE_VALUE="1.5;1;0.1;0.01;0.001;1e-4;1e-5;1e-6;1e-7;1e-8;1e-9;1e-10;"
StrConstant k2336_SENSE_TYPE="Two wire;Four wire"
StrConstant k2336_AUTOZERO_TYPE="Enabled (auto);Only once;Disabled"
StrConstant k2336_SINK_MODE="Disabled;Enabled"
StrConstant k2336_SMUConditionStrPrefix="SMUCondition_Chan"
StrConstant k2336_SMURTUpdateStrPrefix="SMURTUpdate_Chan"

StrConstant k2336_FILTER_TYPE="Disabled;Median;Moving Average;Repeat Average"
StrConstant k2336_initscriptNamePrefix="IgorKeithleyInit_"

