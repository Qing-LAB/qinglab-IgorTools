#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink

StrConstant QDLPackageName="QDataLink"
StrConstant QDL_BACKGROUND_TASK_NAME="QDataLink_Background_Task"

Constant QDL_MAX_CONNECTIONS=5
Constant QDL_DEFAULT_TIMEOUT=10000 //10 sec

Constant QDL_CONNECTION_TYPE_NONE				=0x0000
Constant QDL_CONNECTION_TYPE_SERIAL				=0x0001
Constant QDL_CONNECTION_TYPE_USB					=0x0002
Constant QDL_CONNECTION_TYPE_MASK				=0x00FF
Constant QDL_CONNECTION_QUITTING					=0x8000
Constant QDL_CONNECTION_QUITTED					=0x4000
Constant QDL_CONNECTION_ATTACH_FUNC				=0x2000
Constant QDL_CONNECTION_RUNNING					=0x1000
Constant QDL_CONNECTION_RTCALLBACK_SUSPENSE	=0x0100
Constant QDL_CONNECTION_QUERY_QUIET				=0x0200
Constant QDL_CONNECTION_NO_TIMEOUT				=0x0400

//need national instrument VISA driver support
Constant QDL_VI_EVENT_SERIAL_TERMCHAR=0x3FFF2024
Constant QDL_VI_EVENT_SERIAL_CHAR=0x3FFF2035

Constant QDL_SERIAL_CONNECTION_NAME_MAXLEN=256
Constant QDL_MAX_BUFFER_LEN=16384
Constant QDL_SERIAL_PACKET_BUF_SIZE=64
Constant QDL_EVENT_POLLING_TIMEOUT=50

Constant QDL_REQUEST_READ					=0x0001
Constant QDL_REQUEST_WRITE				=0x0002
Constant QDL_REQUEST_CLEAR_BUFFER		=0x0004
Constant QDL_REQUEST_FLUSH_BUFFER		=0x0008
Constant QDL_REQUEST_STATE_MASK			=0xFFF0 //mask for all event state changes
Constant QDL_REQUEST_READ_BUSY			=0x0010
Constant QDL_REQUEST_WRITE_BUSY			=0x0020
Constant QDL_REQUEST_READ_COMPLETE		=0x0040
Constant QDL_REQUEST_WRITE_COMPLETE		=0x0080
Constant QDL_REQUEST_ERROR_MASK			=0xFF00
Constant QDL_REQUEST_READ_ERROR			=0x0100
Constant QDL_REQUEST_WRITE_ERROR			=0x0200
Constant QDL_REQUEST_TIMEOUT				=0x1000

Constant QDL_RTERROR_THREAD_NOT_INITIALIZED=980 //need to make sure this is defined properly for different Igor version

Constant QDL_THREAD_STATE_FREE			= -1
Constant QDL_THREAD_STATE_RESERVED 		= 0
Constant QDL_THREAD_STATE_RUNNING		= 1

Constant QDL_SLOT_STATE_FREE			=-1
Constant QDL_SLOT_STATE_RESERVED		=-2

//list of global str, var and waves
StrConstant QDLDefaultRMName="visaDefaultRM"
StrConstant QDLWorkerThreadGroupID="threadGroupID"
Strconstant QDLParamAndDataRecord="active_instance_record;connection_param_record;inbox_all;outbox_all;auxparam_all;auxret_all;rt_callback_func_list;post_callback_func_list"
StrConstant QDLStatusRecord="request_record;status_record;connection_type_info;thread_record;"
StrConstant QDLParamAndDataRecordSizes="5"//make sure to have this the same as QDL_MAX_CONNECTIONS
StrConstant QDLStatusRecordSizes="5" //make sure to have this the same as QDL_MAX_CONNECTIONS

//list of local instance str, var and waves for serial connections
StrConstant QDLSerialInstanceVarList="connection_active;count;request_read_len;request_write_len;"
StrConstant QDLSerialInstanceStrList="connection_param;rt_callback_func;post_callback-func;inbox_str;outbox_str;"		

Structure QDLConnectionParam
	uint32 connection_type
	char name[QDL_SERIAL_CONNECTION_NAME_MAXLEN+1]
	uint32 byte_at_port_check_flag
//for serial connections
	uint64 instr
	uint32 baud_rate
	uchar data_bits
	uchar stop_bits
	uchar parity
	uchar flow_control
	uchar xon_char
	uchar xoff_char
	uchar term_char
	uchar end_in
	uchar end_out	
	uint64 starttime_ms
	uint32 timeout_ms
	
//common information
	char packetbuf[QDL_SERIAL_PACKET_BUF_SIZE]
	uint32 packetbuf_start
	uint32 packetbuf_end
	
//	char inbox_buf_name[QDL_SERIAL_CONNECTION_NAME_MAXLEN+1]
	uint32 inbox_request_len
	uint32 inbox_received_len
	uint32 inbox_attempt_count
	
//	char outbox_buf_name[QDL_SERIAL_CONNECTION_NAME_MAXLEN+1]
	uint32 outbox_request_len
	uint32 outbox_retCnt
	uint32 outbox_attempt_count
	
	uint32 instance
	uint32 status
EndStructure