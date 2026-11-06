//
//  HamoTunnelExtension-Bridging-Header.h
//  HamoTunnelExtension
//
//  Legacy filename kept as a thin alias. The real bridging header is
//  Tun2SocksBridge.h, which declares the libXray CGoInvoke/CGoFree API and the
//  hev-socks5-tunnel API actually linked into the extension.
//
//  This file is not part of the CI-built target (only PacketTunnelProvider.swift
//  is added); it only exists because the legacy .c scaffolding files still
//  #include it.
//

#ifndef HamoTunnelExtension_Bridging_Header_h
#define HamoTunnelExtension_Bridging_Header_h

#include "Tun2SocksBridge.h"

#endif /* HamoTunnelExtension_Bridging_Header_h */
