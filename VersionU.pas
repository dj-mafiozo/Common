{$StackFrames On}
Unit VersionU;

Interface

 Type
  TExeVersionInfo = Record
   Public
    Available        : Boolean;
    Major            : Word;
    Minor            : Word;
    Release          : Word;
    Build            : Word;
    FileVersion      : String;
    ProductVersion   : String;
    CompanyName      : String;
    FileDescription  : String;
    InternalName     : String;
    LegalCopyright   : String;
    LegalTrademarks  : String;
    OriginalFilename : String;
    ProductName      : String;
    Comments         : String;
    CFBundleName     : String;
  End;

 Function ReadVersionInfo(Const FileName : String) : TExeVersionInfo;
 Function ExeVersionInfo : TExeVersionInfo;

 Var
  VersionInfo : TExeVersionInfo;

Implementation

 Uses
  Winapi.Windows, System.SysUtils;

 Type
  TTranslation = Packed Record
   Language : Word;
   CodePage : Word;
  End;

  PTranslation = ^TTranslation;

 Function ReadVersionInfo(Const FileName : String) : TExeVersionInfo;
  Var
   Data            : TBytes;
   Size            : DWORD;
   Dummy           : DWORD;
   Len             : DWORD;
   TranslationLen  : DWORD;
   FixedData       : Pointer;
   TranslationData : Pointer;
   TextData        : Pointer;
   Fixed           : PVSFixedFileInfo;

   Function Value(Const Key : String) : String;
    Var
     Path : String;
     J    : Integer;
     Pair : PTranslation;
    Begin
     Result := '';
     For J  := 0 To Integer(TranslationLen Div SizeOf(TTranslation)) - 1 Do
      Begin
       Pair := PTranslation(NativeUInt(TranslationData) + NativeUInt(J * SizeOf(TTranslation)));
       Path := Format('\StringFileInfo\%.4x%.4x\%s', [Pair.Language, Pair.CodePage, Key]);
       If VerQueryValue(Pointer(Data), PChar(Path), TextData, Len) And (Len > 1) Then
        Exit(PChar(TextData));
      End;
     For J := 0 To 1 Do
      Begin
       If J = 0 Then
        Path := '\StringFileInfo\040904E4\' + Key
       Else
        Path := '\StringFileInfo\041504E4\' + Key;
       If VerQueryValue(Pointer(Data), PChar(Path), TextData, Len) And (Len > 1) Then
        Exit(PChar(TextData));
      End;
    End;

  Begin
   Result := Default (TExeVersionInfo);
   Size   := GetFileVersionInfoSize(PChar(FileName), Dummy);
   If Size = 0 Then
    Exit;
   SetLength(Data, Size);
   If Not GetFileVersionInfo(PChar(FileName), 0, Size, Pointer(Data)) Then
    Exit;
   If Not VerQueryValue(Pointer(Data), '\', FixedData, Len) Or (Len < SizeOf(TVSFixedFileInfo)) Then
    Exit;
   Fixed := PVSFixedFileInfo(FixedData);
   If Fixed.dwSignature <> $FEEF04BD Then
    Exit;
   Result.Available := True;
   Result.Major     := HiWord(Fixed.dwFileVersionMS);
   Result.Minor     := LoWord(Fixed.dwFileVersionMS);
   Result.Release   := HiWord(Fixed.dwFileVersionLS);
   Result.Build     := LoWord(Fixed.dwFileVersionLS);
   TranslationLen   := 0;
   TranslationData  := Nil;
   VerQueryValue(Pointer(Data), '\VarFileInfo\Translation', TranslationData, TranslationLen);
   Result.FileVersion      := Format('%d.%d.%d.%d', [Result.Major, Result.Minor, Result.Release, Result.Build]);
   Result.ProductVersion   := Value('ProductVersion');
   Result.CompanyName      := Value('CompanyName');
   Result.FileDescription  := Value('FileDescription');
   Result.InternalName     := Value('InternalName');
   Result.LegalCopyright   := Value('LegalCopyright');
   Result.LegalTrademarks  := Value('LegalTrademarks');
   Result.OriginalFilename := Value('OriginalFilename');
   Result.ProductName      := Value('ProductName');
   Result.Comments         := Value('Comments');
   Result.CFBundleName     := Value('CFBundleName');
  End;

 Function ExeVersionInfo : TExeVersionInfo;
  Begin
   Result := ReadVersionInfo(ParamStr(0));
  End;

Initialization
 VersionInfo := ExeVersionInfo;

End.