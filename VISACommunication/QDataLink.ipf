#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion=7.0
#pragma ModuleName=QDataLink
#include "VISA"
#include "WaveBrowser"
#include "QDataLinkConstants"
#include "QDataLinkBookkeeping"
#include "QDataLinkVISASerial"
#include "QDataLinkCore"
#include "QDataLinkMenu"

///////////////////////////////////////////////////////////
//QDataLink data folder structure
//
//root|Packages|QDataLink
//                maxInstanceRecord
//                infoStr  <- stores active instances, crossrefs between instance# and connection port/names
//                       |privateDF
//                       |strs
//                       |vars
//                           visaDefaultRM <- stores the VISA default resource manager session number, initialized when loaded
//									  threadGroupID <- thread group ID for the thread workers, initialized when loaded
//                       |waves
//									  active_instance_record <- list of active instances for each slot of "active connections"
//                           connection_param_record <- correspondingly, the connection parameters (wave of string storing structure info)
//									  inbox_all <- message received for each active connection, updated in real-time by thread workers
//									  outbox_all <- message to be sent for each active connection
//									  auxparam_all <- auxillary parameters that can be read by thread workers in real-time
//									  auxret_all <- auxillary return information that can be accessed by thread workders
//									  rt_callback_func_list <- list of callback function names, threadsafe, that will be called by thread workders
//									  post_callback_func_list <- list of callback function names, that will be called by background task periodically
//                           request_record  <- request sent each active instances
//                           status_record   <- status returned for each active instances
//									  connection_type_info <- connection type and other information for thread handlers
//                       |instance0 <- holds all information on instance 0
//                       |instance1 <- holds all information on instance 1  <- each connection name will use the same instance # if possible
///////////////////////////////////////////////////////////



