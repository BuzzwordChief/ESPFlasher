//------------------------------------------------------------------------------
#scope_export

// @todo(may): Move this somewhere else. 
//             For now it resides here because we have all the necessary imports...
HandlerRoutine :: #type (dwCtrlType: DWORD) -> void;
SetConsoleCtrlHandler :: (Routine: HandlerRoutine, Add: BOOL) -> BOOL #foreign kernel32;

com_init :: (com_port: u8) -> handle: HANDLE = null, ok := false {
    // Open COM port
    com := CreateFileA(tprint("\\\\.\\COM%", com_port).data, GENERIC_READ | GENERIC_WRITE, 0, null, OPEN_EXISTING, 0, null);
    if com == INVALID_HANDLE_VALUE {
        log_error("Unable to open COM port");
        return;
    }

    // Set COM port settings
    dcb, ok := com_get_dcb(com);
    if !ok {
        log_error("Unable to get comm state: %", GetLastError());
        return;
    }

    return com, true;
}

com_deinit :: (com_handle: HANDLE) {
    CloseHandle(com_handle);
}

// Reads from a given com port. Returned value must be 
// freed by the caller!
//
// note: default is a 1024 byte buffer
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

kernel32 :: #foreign_system_library "kernel32";

SetCommState :: (handle: HANDLE, dcb: *DCB) -> BOOL #foreign kernel32;
GetCommState :: (handle: HANDLE, dcb: *DCB) -> BOOL #foreign kernel32;
PurgeComm    :: (handle: HANDLE, flags: DWORD) -> BOOL #foreign kernel32;

com_get_dcb :: (com_handle: HANDLE) -> DCB, bool {
    dcb: DCB;
    ok := GetCommState(com_handle, *dcb) != 0;
    return dcb, ok;
}
