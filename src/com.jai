//------------------------------------------------------------------------------
#scope_export

// @todo(may): Move this somewhere else. 
//             For now it resides here because we have all the necessary imports...
HandlerRoutine        :: #type (dwCtrlType: DWORD);
SetConsoleCtrlHandler :: (Routine: HandlerRoutine, Add: BOOL) -> BOOL #foreign kernel32;

// Returns an array of active com ports. Returned array is allocated using the
// temp allocator 
com_query :: () -> [] u32 {
    BUFFER_LENGTH :: 255;
    buffer := NewArray(BUFFER_LENGTH, u32, initialized = false, allocator = temp);

    active_ports: u32;
    ok := GetCommPorts(buffer.data, BUFFER_LENGTH, *active_ports);
    assert(ok != 0xEA); // ERROR_MORE_DATA

    buffer.count = active_ports;
    return buffer;
}

com_init :: (com_port: u8, baud_rate: DWORD = 115200) -> handle: HANDLE = null, ok := false {
    // Open COM port
    com := CreateFileA(tprint("\\\\.\\COM%", com_port).data, GENERIC_READ | GENERIC_WRITE, 0, null, OPEN_EXISTING, 0, null);
    if com == INVALID_HANDLE_VALUE {
        log_error("Unable to open COM port %", com_port);
        return;
    }

    // Set COM port settings
    dcb, ok := com_get_dcb(com);
    if !ok {
        log_error("Unable to get comm state: %", GetLastError());
        return;
    }

    dcb.BaudRate = baud_rate;
    dcb.packed_items = 1; // Clear packed_items, only setting fBinary to 1
    dcb.XonChar = 0;      // hterm does the same thing...
    dcb.XoffChar = 0;     // hterm does the same thing...
    if !SetCommState(com, *dcb) {
        log_error("Unable to set DCB: %", GetLastError());
        return;
    }

    com_clear(com); // Clear input + output queue to throw away trash data

    return com, true;
}

com_deinit :: (com_handle: HANDLE) {
    CloseHandle(com_handle);
}

// Reads from a given com port. 
// Returned value must be freed by the caller.
//
// Note: default is a 1024 byte buffer
com_read :: (com_handle: HANDLE, buffer_size: DWORD = DEFAULT_READ_BUFFER_SIZE) -> data := "", ok := false {
    buffer := NewArray(buffer_size, u8, false);
    bytes_read: DWORD;

    if !ReadFile(com_handle, buffer.data, buffer_size, *bytes_read) {
        log_error("Unable to read from COM port");
        return;
    }

    return to_string(buffer.data, bytes_read), true;
}

// Enable/Disable the RTS flag for a given com port
com_rts :: (com_handle: HANDLE, enable: bool) -> ok := false {
    dcb, ok := com_get_dcb(com_handle);
    if !ok then return;

    // @note(may): We want to set/unset the thirteenth bit
    //             in this packed_items element within the DCB
    //             struct. See the declaration of the DCB struct
    //             for more info. 
    if enable {
        dcb.packed_items |= 1 << 13;
    } else {
        dcb.packed_items &= ~(cast(u32)(1 << 13));
    }
    
    if !SetCommState(com_handle, *dcb) {
        return;
    }

    return true;
}

// Clear the input and output queue of a given com port
com_clear :: (com_handle: HANDLE) {
    PurgeComm(com_handle, 0x0008 + 0x0004); // PURGE_TXCLEAR + PURGE_RXCLEAR
}

//------------------------------------------------------------------------------
#scope_file 

#import "Windows";

DEFAULT_READ_BUFFER_SIZE :: 1024;

DCB :: struct {
    DCBlength: DWORD;
    BaudRate:  DWORD;
    
    /*
    DWORD fBinary : 1;
    DWORD fParity : 1;
    DWORD fOutxCtsFlow : 1;
    DWORD fOutxDsrFlow : 1;
    DWORD fDtrControl : 2;
    DWORD fDsrSensitivity : 1;
    DWORD fTXContinueOnXoff : 1;
    DWORD fOutX : 1;
    DWORD fInX : 1;
    DWORD fErrorChar : 1;
    DWORD fNull : 1;
    DWORD fRtsControl : 2;
    DWORD fAbortOnError : 1;
    DWORD fDummy2 : 17;
    */
    packed_items:        u32;

    wReserved:           WORD;
    XonLim:              WORD;
    XoffLim:             WORD;
    ByteSize:            u8;
    Parity:              u8;
    StopBits:            u8;
    XonChar:             s8;
    XoffChar:            s8;
    ErrorChar:           s8;
    EofChar:             s8;
    EvtChar:             s8;
    wReserved1:          WORD;
};

kernel32    :: #foreign_system_library "kernel32";
kernelbase  :: #foreign_system_library "KernelBase";

SetCommState :: (handle: HANDLE, dcb: *DCB) -> BOOL #foreign kernel32;
GetCommState :: (handle: HANDLE, dcb: *DCB) -> BOOL #foreign kernel32;
PurgeComm    :: (handle: HANDLE, flags: DWORD) -> BOOL #foreign kernel32;
GetCommPorts :: (lpPortNumbers: *u32, uPortNumbersCount: u32, puPortNumbersFound: *u32) -> u32 #foreign kernelbase;

com_get_dcb :: (com_handle: HANDLE) -> DCB, bool {
    dcb: DCB;
    dcb.DCBlength = size_of(DCB);
    ok := GetCommState(com_handle, *dcb) != 0;
    return dcb, ok;
}
