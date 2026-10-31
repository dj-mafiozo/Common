{$StackFrames On}

{MIT License

Copyright (c) 2026 dj-mafiozo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.}

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

  TVersionComparison = (vcOlder, vcEqual, vcNewer, vcUnknown);

  TExeVersionInfoHelper = Record Helper For TExeVersionInfo
    Function CompareTo(
      Const aOther: TExeVersionInfo; Const Force : Boolean = False
    ): TVersionComparison;

    Class Function Compare(
      Const A, B: TExeVersionInfo; Const Force : Boolean = False
    ): TVersionComparison; Static;
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

 Function TExeVersionInfoHelper.CompareTo(
  Const aOther: TExeVersionInfo; Const Force : Boolean = False) : TVersionComparison;
  Begin
   Result := vcUnknown;
   If Not (Self.Available And aOther.Available) Then
    Exit;
   If Not (Self.OriginalFilename = OriginalFilename) Then
    Exit;
   If Not (Self.InternalName = aOther.InternalName) Then
    Exit;
   If Not Force Then
    Begin
    If Not (Self.CompanyName = aOther.CompanyName) Then
     Exit;
    If Not (Self.ProductName = aOther.ProductName) Then
     Exit;
    End;
   // Porównanie czterech składników wersji
   If Self.Major = aOther.Major Then
    Begin
     If Self.Minor = aOther.Minor Then
      Begin
       If Self.Release = aOther.Release Then
        Begin
         If Self.Build = aOther.Build Then
          Exit(vcEqual)
         Else If Self.Build > aOther.Build Then
          Exit(vcNewer)
         Else
          Exit(vcOlder);
        End // Wydanie równe
       Else If Self.Release > aOther.Release Then
        Exit(vcNewer)
       Else
        Exit(vcOlder);
      End // Poboczny równy
     Else If Self.Minor > aOther.Minor Then
      Exit(vcNewer)
     Else
      Exit(vcOlder);
    End // Główny równy 
   Else If Self.Major > aOther.Major Then
    Exit(vcNewer)
   Else
    Exit(vcOlder);
  End;

 Class Function TExeVersionInfoHelper.Compare(
  Const A, B: TExeVersionInfo; Const Force : Boolean = False): TVersionComparison;
  Begin 
   Result := A.CompareTo(B, Force);
  End;

Initialization
 VersionInfo := ExeVersionInfo;

End.