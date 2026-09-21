
#ifndef __UHF_H__
#define __UHF_H__


#include <windows.h>

#ifdef __cplusplus
extern "C"
{
#endif

/************************
 * FUNCTION: Connect reader
 * PARAMETERS:
	port: 100->USB, 0->COM1, 1->COM2...
	baud: Baud rate(9600-115200)
 * RETURN: >0 is device handle, otherwise connect failed
 ************************/
int _stdcall uhf_init(int port,long baud); 

/************************
 * FUNCTION: Disconnect reader
 * PARAMETERS:
	icdev: Handle of reader
 * RETURN: 0 if successful; otherwise nonzero
 ************************/
int _stdcall uhf_exit(int icdev)

/************************
 * FUNCTION: Read data from UHF tag
 * PARAMETERS:
	icdev: Handle of reader
	infoType: 1->EPC, 2->TID, 3->USER, 4->reserved
	address: Start address for reading
	rlen: Length of data to read
	pData: Data read
 * RETURN: 0 if successful, otherwise nonzero
 ************************/
int _stdcall uhf_read(int icdev, unsigned char infoType, unsigned int address, unsigned int rlen,
						   unsigned char* pData);

/************************
 * FUNCTION: Write UHF tag
 * PARAMETERS:
	icdev: Handle of reader
	infoType: 1->EPC, 2->TID, 3->USER, 4->reserved
	address: Start address for writing
	wlen: Length of data to write
	pData: Data for write
 * RETURN: 0 if successful, otherwise nonzero
 ************************/
int _stdcall uhf_write(int icdev, unsigned char infoType, unsigned int address, unsigned int wlen,
							unsigned char* pData);

/************************
 * FUNCTION: Control buzzer and led
 * PARAMETERS:
	icdev: Handle of reader
	action: beep:0x01, red led on:0x02, green led on:0x04, yellow led on:0x08
	time: Unit:10ms
 * RETURN: 0 if successful, otherwise nonzero
 ************************/
int _stdcall uhf_action(int icdev,unsigned char action, unsigned char time);

/************************
 * FUNCTION: Set Access Password
 * PARAMETERS:
	icdev: Handle of reader
	AccessPassword: Access password of tag
 * RETURN: 0 if successful, otherwise nonzero
 ************************/
int _stdcall uhf_setAccessPassword(int icdev,unsigned char* AccessPassword);

/************************
 * FUNCTION: Lock Memory
 * PARAMETERS:
	icdev: Handle of reader
	lockSetting: Lock setting, 6 bytes ASCII character
 * RETURN: 0 if successful, otherwise nonzero
 ************************/
int _stdcall uhf_lockMemory(int icdev,unsigned char* lockSetting);

/************************
 * FUNCTION: Multiple EPC reads
 * PARAMETERS:
	icdev: Handle of reader
	tagCount: EPC count read
	dataLen: The length of the data
	pData: Data read (data1_length(1 byte),EPC1_readcount(1 byte),EPC1(data1_length-1 bytes),data2_length(1 byte),EPC2_readcount(1 byte),EPC2(data2_length-1 bytes)...)
 * RETURN: 0 if successful, otherwise nonzero
 ************************/
int _stdcall uhf_inventory(int icdev, unsigned int *tagCount, unsigned int *dataLen,
						   unsigned char* pData);

int _stdcall uhf_commandlink(int icdev,unsigned char slen, unsigned char *sbuff, unsigned char *rlen, unsigned char *rbuff);

#ifdef __cplusplus
}
#endif

#endif