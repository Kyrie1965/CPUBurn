//
//  CPUSensors.m
//  CPUSensors
//
//  Created by Yuri Yuriev on 14.11.11.
//  Copyright (c) 2011 Yuri Yuriev. All rights reserved.
//

/*
 * Apple System Management Control (SMC) Tool
 * Copyright (C) 2006 devnull 
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import "CPUSensors.h"


UInt32 _strtoul(char *str, int size, int base)
{
    UInt32 total = 0;
    int i;
    
    for (i = 0; i < size; i++)
    {
        if (base == 16)
            total += str[i] << (size - 1 - i) * 8;
        else
            total += (unsigned char) (str[i] << (size - 1 - i) * 8);
    }
    return total;
}


void _ultostr(char *str, UInt32 val)
{
    str[0] = '\0';
    sprintf(str, "%c%c%c%c", 
            (unsigned int) val >> 24,
            (unsigned int) val >> 16,
            (unsigned int) val >> 8,
            (unsigned int) val);
}


float _strtof(char *str, int size, int e)
{
    float total = 0;
    int i;
    
    for (i = 0; i < size; i++)
    {
        if (i == (size - 1))
            total += (str[i] & 0xff) >> e;
        else
            total += str[i] << (size - 1 - i) * (8 - e);
    }
    
    return total;
}


kern_return_t SMCCall(io_connect_t conn, int index, SMCKeyData_t *inputStructure, SMCKeyData_t *outputStructure)
{
    IOItemCount   structureInputSize;
    size_t   structureOutputSize;
    
    structureInputSize = sizeof(SMCKeyData_t);
    structureOutputSize = sizeof(SMCKeyData_t);
    
    return IOConnectCallStructMethod(conn,
                                     index,
                                     inputStructure,
                                     structureInputSize,
                                     outputStructure,
                                     &structureOutputSize
                                     );
}


kern_return_t SMCReadKey(io_connect_t conn, UInt32Char_t key, SMCVal_t *val)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;
    
    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));
    
    
    inputStructure.key = _strtoul(key, 4, 16);
    sprintf(val->key, "%s", key);
    inputStructure.data8 = SMC_CMD_READ_KEYINFO;    
    
    result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;
    
    val->dataSize = outputStructure.keyInfo.dataSize;
    _ultostr(val->dataType, outputStructure.keyInfo.dataType);
    inputStructure.keyInfo.dataSize = val->dataSize;
    inputStructure.data8 = SMC_CMD_READ_BYTES;
    
    result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;
    
    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));
    
    return kIOReturnSuccess;
}


UInt32 SMCReadIndexCount(io_connect_t conn)
{
    SMCVal_t val;
    
    if ((SMCReadKey(conn, "#KEY", &val) == kIOReturnSuccess) && (strcmp(val.dataType, DATATYPE_UINT32) == 0))
    {
        UInt32 l = 0;
        l |= val.bytes[0] & 0xFF;
        l <<= 8;
        l |= val.bytes[1] & 0xFF;
        l <<= 8;
        l |= val.bytes[2] & 0xFF;
        l <<= 8;
        l |= val.bytes[3] & 0xFF;
        
        return l;
    }
    
    return 0;
}


@implementation CPUSensors


- (id)init
{
    self = [super init];
    
    initDone = NO;
    sensors = [[NSMutableArray alloc] initWithCapacity:10];
    
    kern_return_t result;
    mach_port_t   masterPort;
    io_iterator_t iterator;
    io_object_t   device;
    
    result = IOMasterPort(MACH_PORT_NULL, &masterPort);
    
    CFMutableDictionaryRef matchingDictionary = IOServiceMatching("AppleSMC");
    result = IOServiceGetMatchingServices(masterPort, matchingDictionary, &iterator);
    if (result != kIOReturnSuccess)
    {
        return self;
    }
    
    device = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (device == 0)
    {
        return self;
    }
    
    result = IOServiceOpen(device, mach_task_self(), 0, &conn);
    IOObjectRelease(device);
    if (result != kIOReturnSuccess)
    {
        return self;
    }
    
    
    initDone = YES;

    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    int           totalKeys, i;
    UInt32Char_t  key;
    SMCVal_t      val;

    totalKeys = SMCReadIndexCount(conn);
    
    for (i = 0; i < totalKeys; i++)
    {
        memset(&inputStructure, 0, sizeof(SMCKeyData_t));
        memset(&outputStructure, 0, sizeof(SMCKeyData_t));
        memset(&val, 0, sizeof(SMCVal_t));
        
        inputStructure.data8 = SMC_CMD_READ_INDEX;
        inputStructure.data32 = i;
        
        result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
        
        if (result != kIOReturnSuccess) continue;
        
        _ultostr(key, outputStructure.key); 
        
        result = SMCReadKey(conn, key, &val);
        
        if (result != kIOReturnSuccess) continue;

        NSString *keyStr = [NSString stringWithFormat:@"%-4s", val.key];
        
        if ([keyStr hasPrefix:@"TC"] && (val.dataSize > 0) && (strcmp(val.dataType, DATATYPE_SP78) == 0))
        {
            int intValue = (val.bytes[0] * 256 + val.bytes[1]) >> 2;
            double temperature =  intValue / 64.0;

            if (temperature > 0)
            {
                NSMutableDictionary *tmpDict = [NSMutableDictionary dictionaryWithCapacity:3];
                [tmpDict setObject:keyStr forKey:@"key"];
                [tmpDict setObject:[NSNumber numberWithDouble:temperature] forKey:@"currentTemperature"];
                [tmpDict setObject:[NSNumber numberWithDouble:temperature] forKey:@"maxTemperature"];
                
                [sensors addObject:tmpDict];
            }
        }
    }
    
    return self;;
}

- (void)dealloc
{
    if (initDone) IOServiceClose(conn);
    [sensors release];
    
    [super dealloc];
}

- (void)updateSensors
{
    if (!initDone) return;
    
    for (int i = 0; i < [sensors count]; i++)
    {
        SMCVal_t val;
        kern_return_t result;
        UInt32Char_t  key;
        sprintf(key, "%s", [[[sensors objectAtIndex:i] objectForKey:@"key"] cStringUsingEncoding:NSASCIIStringEncoding]);
        
        result = SMCReadKey(conn, key, &val);
        if (result == kIOReturnSuccess)
        {
            if (val.dataSize > 0)
            {
                if (strcmp(val.dataType, DATATYPE_SP78) == 0)
                {
                    int intValue = (val.bytes[0] * 256 + val.bytes[1]) >> 2;
                    double temperature =  intValue / 64.0;
                    
                    if (temperature > 0)
                    {
                        NSMutableDictionary *tmpDict = [sensors objectAtIndex:i];
                        [tmpDict setObject:[NSNumber numberWithDouble:temperature] forKey:@"currentTemperature"];
                        
                        if ([[tmpDict objectForKey:@"maxTemperature"] doubleValue] < temperature)
                        {
                            [tmpDict setObject:[NSNumber numberWithDouble:temperature] forKey:@"maxTemperature"];
                        }
                    }

                }
            }
        }
    }
}

- (NSArray *)sensorsData
{
    return [NSArray arrayWithArray:sensors];
}

@end
