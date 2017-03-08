library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Rhody_CPU_pipelinev42 is 
  port (	clk		: in	std_logic;
			rst		: in	std_logic;
			MEM_ADR	: out	std_logic_vector(31 downto 0);
			MEM_IN	: in  std_logic_vector(31 downto 0);
			MEM_OUT	: out std_logic_vector(31 downto 0);
	      mem_wr	: out std_logic;
			mem_rd	: out std_logic;
			key 		: in	std_logic;
			LEDR 		: out std_logic_vector(3 downto 0)
		);
end;

architecture Structural of Rhody_CPU_pipelinev42 is
-- state machine: CPU_state
type State_type is (S1, S2);
signal update, stage1, stage2, stage3, stage4: State_type;
-- Register File: 8x32
type reg_file_type is array (0 to 7) of std_logic_vector(31 downto 0);
signal register_file : reg_file_type;
-- Internal registers
signal MDR_in, MDR_out, MAR, PSW: std_logic_vector(31 downto 0);
signal PC, SP: unsigned(31 downto 0);  --unsigned for arithemtic operations
-- Internal control signals
signal operand0, operand1, ALU_out : std_logic_vector(31 downto 0);
signal carry, overflow, zero : std_logic;	
-- Pipeline Istruction registers
signal stall: Boolean;
signal IR2, IR3, IR4: std_logic_vector(31 downto 0);
--Rhody Instruction Format
alias Opcode2: std_logic_vector(5 downto 0) is IR2(31 downto 26);
alias Opcode3: std_logic_vector(5 downto 0) is IR3(31 downto 26);
alias Opcode4: std_logic_vector(5 downto 0) is IR4(31 downto 26);
alias	RX2	: std_logic_vector(2 downto 0) is IR2(25 downto 23); 
alias	RX3	: std_logic_vector(2 downto 0) is IR3(25 downto 23); 
alias RX4	: std_logic_vector(2 downto 0) is IR4(25 downto 23); 
alias	RY2	: std_logic_vector(2 downto 0) is IR2(22 downto 20);
alias	RY3	: std_logic_vector(2 downto 0) is IR3(22 downto 20);
alias 	RZ2		: std_logic_vector(2 downto 0) is IR2(19 downto 17);
alias 	RA2		: std_logic_vector(2 downto 0) is IR2(16 downto 14);
alias	RB2		: std_logic_vector(2 downto 0) is IR2(13 downto 11);
alias	RB3		: std_logic_vector(2 downto 0) is IR2(13 downto 11);
alias 	RC2		: std_logic_vector(2 downto 0) is IR2(10 downto 8);
alias 	RC3		: std_logic_vector(2 downto 0) is IR2(10 downto 8);
alias 	RD2		: std_logic_vector(2 downto 0) is IR2(7 downto 5);
alias 	RE2		: std_logic_vector(2 downto 0) is IR2(4 downto 2);
alias I2		: std_logic_vector(15 downto 0) is IR2(15 downto 0);
alias M2		: std_logic_vector(19 downto 0) is IR2(19 downto 0);
alias M3		: std_logic_vector(19 downto 0) is IR3(19 downto 0);
-- Temporary control signals
	signal tmpx, tmpy, tmpz, tmpa: std_logic_vector(31 downto 0);
	signal tmpxx: std_logic_vector(19 downto 0);
	signal tmpyy: std_logic_vector(31 downto 0);
--Condition Codes
alias Z: std_logic is PSW(0);
alias C: std_logic is PSW(1);
alias S: std_logic is PSW(2);
alias V: std_logic is PSW(3);
--Instruction Opcodes
constant NOP  : std_logic_vector(5 downto 0) := "000000";
--constant ADD64: std_logic_vector(5 downto 0) := "000001";
constant LDMD2  : std_logic_vector(5 downto 0) := "000010";

constant LDM  : std_logic_vector(5 downto 0) := "000100";
constant LDR  : std_logic_vector(5 downto 0) := "000101";
--constant LDIX : std_logic_vector(5 downto 0) := "000110";
--constant STIX : std_logic_vector(5 downto 0) := "000111";
constant LDH  : std_logic_vector(5 downto 0) := "001000";
constant LDL  : std_logic_vector(5 downto 0) := "001001";
constant LDI  : std_logic_vector(5 downto 0) := "001010";
constant MOV  : std_logic_vector(5 downto 0) := "001011";
constant STM  : std_logic_vector(5 downto 0) := "001100";
constant STR  : std_logic_vector(5 downto 0) := "001101";

constant ADD  : std_logic_vector(5 downto 0) := "010000";
constant ADI  : std_logic_vector(5 downto 0) := "010001";
constant SUB  : std_logic_vector(5 downto 0) := "010010";
constant MUL  : std_logic_vector(5 downto 0) := "010011";
constant IAND : std_logic_vector(5 downto 0) := "010100"; --avoid keyword
constant IOR  : std_logic_vector(5 downto 0) := "010101"; --avoid keyword
constant IXOR : std_logic_vector(5 downto 0) := "010110"; --avoid keyword
constant IROR : std_logic_vector(5 downto 0) := "010111"; --avoid keyword




constant JNZ 		: std_logic_vector(5 downto 0) := "100000";
constant JNS  		: std_logic_vector(5 downto 0) := "100001";
constant JNV  		: std_logic_vector(5 downto 0) := "100010";
constant JNC  		: std_logic_vector(5 downto 0) := "100011";
constant JZ   		: std_logic_vector(5 downto 0) := "100100";
constant JS   		: std_logic_vector(5 downto 0) := "100101";
constant JV   		: std_logic_vector(5 downto 0) := "100110";
constant JC   		: std_logic_vector(5 downto 0) := "100111";
constant JMP  		: std_logic_vector(5 downto 0) := "101000";



constant CMP 		: std_logic_vector(5 downto 0) := "101010";


--constant T11  		: std_logic_vector(5 downto 0) := "101110";
--constant T12  		: std_logic_vector(5 downto 0) := "101111";

constant CALL 		: std_logic_vector(5 downto 0) := "110000";

constant CMPI 		: std_logic_vector(5 downto 0) := "110010";

constant RET  		: std_logic_vector(5 downto 0) := "110100";
constant RETI		: std_logic_vector(5 downto 0) := "110101";

constant PUSH 		: std_logic_vector(5 downto 0) := "111000";
constant POP  		: std_logic_vector(5 downto 0) := "111001";

constant SYS  		: std_logic_vector(5 downto 0) := "111100";
constant SIG0 		: std_logic_vector(5 downto 0) := "111110";
constant SIG1 		: std_logic_vector(5 downto 0) := "111111";

constant MLOAD0   : std_logic_vector(5 downto 0) := "011001";
constant MLOAD1   : std_logic_vector(5 downto 0) := "011010";
constant MLOAD2   : std_logic_vector(5 downto 0) := "011011";
constant MLOAD3   : std_logic_vector(5 downto 0) := "011100";
constant WLOAD		: std_logic_vector(5 downto 0) := "011101";
constant STMD		: std_logic_vector(5 downto 0) := "101100";
constant FIN		: std_logic_vector(5 downto 0) := "101101";
constant MSTM0  	: std_logic_vector(5 downto 0) := "101001";
constant MSTM1   	: std_logic_vector(5 downto 0) := "101011";
constant LDMD  	: std_logic_vector(5 downto 0) := "111010";
constant WPAD		: std_logic_vector(5 downto 0) := "111011";







constant  WORD_BITS : integer := 64;
subtype   WORD_TYPE      is std_logic_vector(63 downto 0);
type      WORD_VECTOR    is array (INTEGER range <>) of WORD_TYPE;
constant  WORD_NULL : WORD_TYPE := (others => '0');
--shared variable w_80 : WORD_VECTOR(0 to 79);
----------------------------------------------------------------
constant  K_TABLE         : WORD_VECTOR(0 to 79) := (
        0  => To_StdLogicVector(bit_vector'(X"428a2f98d728ae22")),
        1  => To_StdLogicVector(bit_vector'(X"7137449123ef65cd")),
        2  => To_StdLogicVector(bit_vector'(X"b5c0fbcfec4d3b2f")),
        3  => To_StdLogicVector(bit_vector'(X"e9b5dba58189dbbc")),
        4  => To_StdLogicVector(bit_vector'(X"3956c25bf348b538")),
        5  => To_StdLogicVector(bit_vector'(X"59f111f1b605d019")),
        6  => To_StdLogicVector(bit_vector'(X"923f82a4af194f9b")),
        7  => To_StdLogicVector(bit_vector'(X"ab1c5ed5da6d8118")),
        8  => To_StdLogicVector(bit_vector'(X"d807aa98a3030242")),
        9  => To_StdLogicVector(bit_vector'(X"12835b0145706fbe")),
       10  => To_StdLogicVector(bit_vector'(X"243185be4ee4b28c")),
       11  => To_StdLogicVector(bit_vector'(X"550c7dc3d5ffb4e2")),
       12  => To_StdLogicVector(bit_vector'(X"72be5d74f27b896f")),
       13  => To_StdLogicVector(bit_vector'(X"80deb1fe3b1696b1")),
       14  => To_StdLogicVector(bit_vector'(X"9bdc06a725c71235")),
       15  => To_StdLogicVector(bit_vector'(X"c19bf174cf692694")),
       16  => To_StdLogicVector(bit_vector'(X"e49b69c19ef14ad2")),
       17  => To_StdLogicVector(bit_vector'(X"efbe4786384f25e3")),
       18  => To_StdLogicVector(bit_vector'(X"0fc19dc68b8cd5b5")),
       19  => To_StdLogicVector(bit_vector'(X"240ca1cc77ac9c65")),
       20  => To_StdLogicVector(bit_vector'(X"2de92c6f592b0275")),
       21  => To_StdLogicVector(bit_vector'(X"4a7484aa6ea6e483")),
       22  => To_StdLogicVector(bit_vector'(X"5cb0a9dcbd41fbd4")),
       23  => To_StdLogicVector(bit_vector'(X"76f988da831153b5")),
       24  => To_StdLogicVector(bit_vector'(X"983e5152ee66dfab")),
       25  => To_StdLogicVector(bit_vector'(X"a831c66d2db43210")),
       26  => To_StdLogicVector(bit_vector'(X"b00327c898fb213f")),
       27  => To_StdLogicVector(bit_vector'(X"bf597fc7beef0ee4")),
       28  => To_StdLogicVector(bit_vector'(X"c6e00bf33da88fc2")),
       29  => To_StdLogicVector(bit_vector'(X"d5a79147930aa725")),
       30  => To_StdLogicVector(bit_vector'(X"06ca6351e003826f")),
       31  => To_StdLogicVector(bit_vector'(X"142929670a0e6e70")),
       32  => To_StdLogicVector(bit_vector'(X"27b70a8546d22ffc")),
       33  => To_StdLogicVector(bit_vector'(X"2e1b21385c26c926")),
       34  => To_StdLogicVector(bit_vector'(X"4d2c6dfc5ac42aed")),
       35  => To_StdLogicVector(bit_vector'(X"53380d139d95b3df")),
       36  => To_StdLogicVector(bit_vector'(X"650a73548baf63de")),
       37  => To_StdLogicVector(bit_vector'(X"766a0abb3c77b2a8")),
       38  => To_StdLogicVector(bit_vector'(X"81c2c92e47edaee6")),
       39  => To_StdLogicVector(bit_vector'(X"92722c851482353b")),
       40  => To_StdLogicVector(bit_vector'(X"a2bfe8a14cf10364")),
       41  => To_StdLogicVector(bit_vector'(X"a81a664bbc423001")),
       42  => To_StdLogicVector(bit_vector'(X"c24b8b70d0f89791")),
       43  => To_StdLogicVector(bit_vector'(X"c76c51a30654be30")),
       44  => To_StdLogicVector(bit_vector'(X"d192e819d6ef5218")),
       45  => To_StdLogicVector(bit_vector'(X"d69906245565a910")),
       46  => To_StdLogicVector(bit_vector'(X"f40e35855771202a")),
       47  => To_StdLogicVector(bit_vector'(X"106aa07032bbd1b8")),
       48  => To_StdLogicVector(bit_vector'(X"19a4c116b8d2d0c8")),
       49  => To_StdLogicVector(bit_vector'(X"1e376c085141ab53")),
       50  => To_StdLogicVector(bit_vector'(X"2748774cdf8eeb99")),
       51  => To_StdLogicVector(bit_vector'(X"34b0bcb5e19b48a8")),
       52  => To_StdLogicVector(bit_vector'(X"391c0cb3c5c95a63")),
       53  => To_StdLogicVector(bit_vector'(X"4ed8aa4ae3418acb")),
       54  => To_StdLogicVector(bit_vector'(X"5b9cca4f7763e373")),
       55  => To_StdLogicVector(bit_vector'(X"682e6ff3d6b2b8a3")),
       56  => To_StdLogicVector(bit_vector'(X"748f82ee5defb2fc")),
       57  => To_StdLogicVector(bit_vector'(X"78a5636f43172f60")),
       58  => To_StdLogicVector(bit_vector'(X"84c87814a1f0ab72")),
       59  => To_StdLogicVector(bit_vector'(X"8cc702081a6439ec")),
       60  => To_StdLogicVector(bit_vector'(X"90befffa23631e28")),
       61  => To_StdLogicVector(bit_vector'(X"a4506cebde82bde9")),
       62  => To_StdLogicVector(bit_vector'(X"bef9a3f7b2c67915")),
       63  => To_StdLogicVector(bit_vector'(X"c67178f2e372532b")),
       64  => To_StdLogicVector(bit_vector'(X"ca273eceea26619c")),
       65  => To_StdLogicVector(bit_vector'(X"d186b8c721c0c207")),
       66  => To_StdLogicVector(bit_vector'(X"eada7dd6cde0eb1e")),
       67  => To_StdLogicVector(bit_vector'(X"f57d4f7fee6ed178")),
       68  => To_StdLogicVector(bit_vector'(X"06f067aa72176fba")),
       69  => To_StdLogicVector(bit_vector'(X"0a637dc5a2c898a6")),
       70  => To_StdLogicVector(bit_vector'(X"113f9804bef90dae")),
       71  => To_StdLogicVector(bit_vector'(X"1b710b35131c471b")),
       72  => To_StdLogicVector(bit_vector'(X"28db77f523047d84")),
       73  => To_StdLogicVector(bit_vector'(X"32caab7b40c72493")),
       74  => To_StdLogicVector(bit_vector'(X"3c9ebe0a15c9bebc")),
       75  => To_StdLogicVector(bit_vector'(X"431d67c49c100d4c")),
       76  => To_StdLogicVector(bit_vector'(X"4cc5d4becb3e42b6")),
       77  => To_StdLogicVector(bit_vector'(X"597f299cfc657e2a")),
       78  => To_StdLogicVector(bit_vector'(X"5fcb6fab3ad6faec")),
       79  => To_StdLogicVector(bit_vector'(X"6c44198c4a475817"))
    );

 constant  H0_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"6a09e667f3bcc908"));
 constant  H1_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"bb67ae8584caa73b"));
 constant  H2_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"3c6ef372fe94f82b"));
 constant  H3_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"a54ff53a5f1d36f1"));
 constant  H4_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"510e527fade682d1"));
 constant  H5_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"9b05688c2b3e6c1f"));
 constant  H6_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"1f83d9abfb41bd6b"));
 constant  H7_INIT   : WORD_TYPE := To_StdLogicVector(bit_vector'(X"5be0cd19137e2179"));
 
-------------------------------------------------------------------------


 -- a,b,c,d,e,f,g,h
 
 signal    wva         : WORD_TYPE;
 signal    wvb         : WORD_TYPE;
 signal    wvc         : WORD_TYPE;
 signal    wvd         : WORD_TYPE;
 signal    wve         : WORD_TYPE;
 signal    wvf         : WORD_TYPE;
 signal    wvg         : WORD_TYPE;
 signal    wvh         : WORD_TYPE;
 
 signal	  t1_val		  : WORD_TYPE;
 signal	  t2_val		  : WORD_TYPE;
 

 -- H0,H1,H2,H3,H4,H5,H6,H7

 signal    h0        : WORD_TYPE;
 signal    h1        : WORD_TYPE;
 signal    h2        : WORD_TYPE;
 signal    h3        : WORD_TYPE;
 signal    h4        : WORD_TYPE;
 signal    h5  		: WORD_TYPE;
 signal    h6   		: WORD_TYPE;
 signal    h7        : WORD_TYPE;
 
 signal rcount : std_logic_vector(31 downto 0);
 
 signal tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7: std_logic_vector(63 downto 0);

signal mvect : WORD_VECTOR(0 to 15);
signal dvect : WORD_VECTOR(0 to 7);


signal wout: std_logic_vector(63 downto 0);
signal lcount: std_logic_vector(31 downto 0);
signal scount: std_logic_vector(31 downto 0);

begin
--Display condition code on LEDR for debugging purpose
LEDR(3) <= Z when key='0' else '0';
LEDR(2) <= C when key='0' else '0';
LEDR(1) <= S when key='0' else '0';
LEDR(0) <= V when key='0' else '0';
--CPU bus interface
MEM_OUT <= MDR_out;	--Outgoing data bus
MEM_ADR <= MAR;		--Address bus
--One clock cycle delay in obtaining CPU_state, e.g. S1->S2
mem_rd	<=	'1' when ((Opcode2=LDM or Opcode2=LDR or Opcode2=LDMD) and stage2=S2) else
				'1' when (stage1=S2 and not stall) else
				'1' when ((Opcode2=POP or Opcode2=RET) and stage2=S2) else
				'1' when (Opcode2=RETI and stage2=S2) else
				'1' when ((Opcode3=RETI or Opcode3=LDMD) and stage3=S2) else
				'0';		--Memory read control signal
mem_wr	<=	'1' when ((Opcode3=STM or Opcode3=STR or Opcode3 = STMD) and stage3=S1) else
				'1' when ((Opcode3=PUSH or Opcode3=CALL) and stage3=S2) else
				'1' when (Opcode3=SYS and stage3=S2) else	
				'1' when ((Opcode4=SYS or Opcode4=STMD) and stage4=S2) else			
				'0';		--Memory write control signal
stall <= true when(Opcode2=LDM or Opcode2=LDR or Opcode2=STM or Opcode2=STR or Opcode2=WPAD or Opcode2 = LDMD or Opcode2 = STMD) else
			true when(Opcode2=CALL or Opcode2=PUSH or Opcode2=POP or Opcode2=RET
							or Opcode2=SYS or Opcode2=RETI) else
			true when(Opcode3=CALL  or Opcode3=RET	or Opcode3=PUSH
							or Opcode3=SYS or Opcode3=RETI or Opcode3=LDMD or Opcode3 = STMD or Opcode3 = WPAD) else
			true when(Opcode4=SYS or Opcode4=RETI or Opcode4 = STMD) else
			false;
--The state machine that is CPU
CPU_State_Machine: process (clk, rst)
begin
if rst='1' then
	update <= S1;
	stage1 <= S1;
	stage2 <= S1;
	stage3 <= S1;
	stage4 <= S1;
	rcount <= x"00000000";
	lcount <= x"00000000";
	scount <= x"00000000";
				 h0       <= H0_INIT;
				 h1       <= H1_INIT;
				 h2       <= H2_INIT;
				 h3       <= H3_INIT;
				 h4       <= H4_INIT;
				 h5       <= H5_INIT;
				 h6       <= H6_INIT;
				 h7       <= H7_INIT;
				 wva      <= H0_INIT;
				 wvb      <= H1_INIT;
				 wvc      <= H2_INIT;
				 wvd      <= H3_INIT;
				 wve      <= H4_INIT;
				 wvf      <= H5_INIT;
				 wvg      <= H6_INIT;
				 wvh  	 <= H7_INIT;
	t1_val <= X"0000000000000000";
	t2_val <= X"0000000000000000";


	PC <= x"00000000";	--initialize PC
	SP <= x"000FF7FF";	--initialize SP
	IR2 <= x"00000000";
	IR3 <= x"00000000";
	IR4 <= x"00000000";
elsif clk'event and clk = '1' then

	case update is
		when S1 =>
			update <= S2;
		when S2 =>
			if (stall or
				(Opcode2=JNZ and Z='1') or (Opcode2=JZ and Z='0') or
				(Opcode2=JNS and S='1') or (Opcode2=JS and S='0') or
				(Opcode2=JNV and V='1') or (Opcode2=JV and V='0') or
				(Opcode2=JNC and C='1') or (Opcode2=JC and C='0') ) then
				IR2 <= x"00000000";	--insert NOP
			else
				IR2 <= MEM_in;
			end if;
			IR3 <= IR2;
			IR4 <= IR3;
			update <= S1;
		when others =>
			null;
	end case;

	case stage1 is
		when S1 =>
			if (not stall) then
				if(Opcode2=JMP or Opcode2=JNZ or Opcode2=JZ or Opcode2=JNS or
					Opcode2=JS or Opcode2=JNV or Opcode2=JV or 
					Opcode2=JNC or Opcode2=JC) then
					MAR <= x"000" & M2;
			else
				MAR <= std_logic_vector(PC);
			end if;
		end if;
			stage1 <= S2;
		when S2 =>
			if (not stall) then
				if (Opcode2=JMP or
					 (Opcode2=JNZ and Z='0') or (Opcode2=JZ and Z='1') or
					 (Opcode2=JNS and S='0') or (Opcode2=JS and S='1') or
					 (Opcode2=JNV and V='0') or (Opcode2=JV and V='1') or
					 (Opcode2=JNC and C='0') or (Opcode2=JC and C='1') ) then
				PC <= (x"000" & unsigned(M2))+1;
			elsif ((Opcode2=JNZ and Z='1') or (Opcode2=JZ and Z = '0') or 
			(Opcode2=JNS and S = '1')or (Opcode2=JS and S = '0') or
			(Opcode2=JNV and V = '1') or (Opcode2=JV and V = '0') or
			(Opcode2=JNC and C = '1') or (Opcode2=JC and C = '0')) then
				null;
			else
				PC <= PC + 1;
			end if;
		end if;
			stage1 <= S1;
		when others =>
			null;
	end case;

	case stage2 is
		when S1 =>
		if (Opcode2=LDI) then
				register_file(to_integer(unsigned(RX2)))<=(31 downto 16=>I2(15)) & I2;
			elsif (Opcode2=LDH) then
				register_file(to_integer(unsigned(RX2)))
					<= I2 & register_file(to_integer(unsigned(RX2)))(15 downto 0);
					--(31 downto 16)<= I2;
			elsif (Opcode2=LDL) then
				register_file(to_integer(unsigned(RX2)))
					<= register_file(to_integer(unsigned(RX2)))(31 downto 16) & I2;
					--(15 downto 0)<= I2;
			elsif (Opcode2=MOV) then
				register_file(to_integer(unsigned(RX2)))<=register_file(to_integer(unsigned(RY2)));	
			elsif (Opcode2=ADD or Opcode2=SUB or Opcode2=MUL or Opcode2=CMP or
					 Opcode2=IAND or Opcode2=IOR or Opcode2=IXOR) then
				operand1 <= register_file(to_integer(unsigned(RY2)));
			elsif (Opcode2=IROR) then
				null;
			elsif (Opcode2=ADI or Opcode2=CMPI) then
				operand1 <= (31 downto 16=>I2(15)) & I2;
			elsif (Opcode2=LDM or Opcode2 = LDMD) then
				MAR <= x"000" & M2;
				tmpxx <= std_logic_vector((unsigned(M2) + 1));
			elsif (Opcode2=LDR) then
				MAR <= register_file(to_integer(unsigned(RY2)));
			elsif (Opcode2=STM) then
				MAR <= x"000" & M2;	MDR_out <= register_file(to_integer(unsigned(RX2)));
			elsif (Opcode2=STMD) then
			dvect(0) <= std_logic_vector(unsigned(wva) + unsigned(h0));
			dvect(1) <= std_logic_vector(unsigned(wvb) + unsigned(h1));
			dvect(2) <= std_logic_vector(unsigned(wvc) + unsigned(h2));
			dvect(3) <= std_logic_vector(unsigned(wvd) + unsigned(h3));
			dvect(4) <= std_logic_vector(unsigned(wve) + unsigned(h4));
			dvect(5) <= std_logic_vector(unsigned(wvf) + unsigned(h5));
			dvect(6) <= std_logic_vector(unsigned(wvg) + unsigned(h6));
			dvect(7) <= std_logic_vector(unsigned(wvh) + unsigned(h7));
				MAR <= x"000" & M2;	
				MDR_out <= dvect(to_integer(unsigned(scount)))(63 downto 32);
				tmpyy <= x"000" & std_logic_vector(unsigned(M2) + 1);
			elsif (Opcode2=STR) then
				MAR <= register_file(to_integer(unsigned(RX2)));	
				MDR_out <= register_file(to_integer(unsigned(RY2)));
			elsif (Opcode2=JMP or
					 (Opcode2=JNZ and Z='0') or (Opcode2=JZ and Z='1') or
					 (Opcode2=JNS and S='0') or (Opcode2=JS and S='1') or
					 (Opcode2=JNV and V='0') or (Opcode2=JV and V='1') or
					 (Opcode2=JNC and C='0') or (Opcode2=JC and C='1') ) then
				PC <= x"000" & unsigned(M2);
			elsif (Opcode2=CALL or Opcode2=PUSH or Opcode2=SYS) then
				SP <= SP + 1;
			elsif (Opcode2=RET or Opcode2=RETI or Opcode2=POP) then
				MAR <= std_logic_vector(SP);	 
			elsif (Opcode2 = WPAD) then
				if (to_integer(unsigned(rcount)) < 1) then
				 h0       <= H0_INIT;
				 h1       <= H1_INIT;
				 h2       <= H2_INIT;
				 h3       <= H3_INIT;
				 h4       <= H4_INIT;
				 h5       <= H5_INIT;
				 h6       <= H6_INIT;
				 h7       <= H7_INIT;
				 wva      <= H0_INIT;
				 wvb      <= H1_INIT;
				 wvc      <= H2_INIT;
				 wvd      <= H3_INIT;
				 wve      <= H4_INIT;
				 wvf      <= H5_INIT;
				 wvg      <= H6_INIT;
				 wvh  	 <= H7_INIT;
				end if;
				if (to_integer(unsigned(rcount)) < 16) then
				wout <= std_logic_vector(mvect(to_integer(unsigned(rcount))));
				else 
				wout <= std_Logic_vector(
						unsigned(unsigned(rotate_right(unsigned(mvect(14)),19)) xor unsigned(rotate_right(unsigned(mvect(14)),61)) xor unsigned(shift_right(unsigned(mvect(14)),6))) +
						unsigned(mvect(9)) +
						unsigned(unsigned(rotate_right(unsigned(mvect(1)),1)) xor unsigned(rotate_right(unsigned(mvect(1)),8)) xor unsigned(shift_right(unsigned(mvect(1)),7))) +
						unsigned(mvect(0)));
				end if;
			end if;			
			stage2 <= S2;
		when S2 =>
			if (Opcode2=ADD or Opcode2=SUB or Opcode2=IROR or Opcode2=IAND or
					 Opcode2=MUL or Opcode2=IOR or Opcode2=IXOR or Opcode2=ADI) then
				register_file(to_integer(unsigned(RX2))) <= ALU_out;
				Z <= zero;	S <= ALU_out(31);	V <= overflow;	C <= carry; --update CC
			elsif (Opcode2=CMP or Opcode2=CMPI) then
				Z <= zero;	S <= ALU_out(31);	V <= overflow;	C <= carry; --update CC only
			elsif (Opcode2=LDM or Opcode2=LDR or Opcode2 = LDMD) then
				MDR_in <= MEM_in;
			elsif (Opcode2=STM or Opcode2=STR) then
				null;
			elsif(Opcode2=STMD) then
				register_file(to_integer(unsigned(RX3))) <= MAR;
			elsif (Opcode2=CALL or Opcode2=SYS) then
				MAR <= std_logic_vector(SP);	
				MDR_out <= std_logic_vector(PC);	
			elsif (Opcode2=RET or Opcode2=RETI or Opcode2=POP) then
				MDR_in <= MEM_IN;	SP <= SP - 1;
			elsif (Opcode2=PUSH) then
				MAR <= std_logic_vector(SP);
				MDR_out <= register_file(to_integer(unsigned(RX2)));
			elsif (Opcode2 = WPAD) then
			t1_val <= std_logic_vector(
							(unsigned(wvh) + 
							(unsigned(rotate_right(unsigned(wve), 14)) xor unsigned(rotate_right(unsigned(wve), 18)) xor unsigned(rotate_right(unsigned(wve), 41))) +
							((unsigned(wve) and unsigned(wvf)) xor (not(unsigned(wve)) and unsigned(wvg))) +
							(unsigned(K_TABLE(to_integer(unsigned(rcount)))) + unsigned(wout))
							));	
			t2_val <= std_logic_vector(
							(unsigned(rotate_right(unsigned(wva), 28)) xor unsigned(rotate_right(unsigned(wva), 34)) xor unsigned(rotate_right(unsigned(wva), 39))) +
							(((unsigned(wva)) and (unsigned(wvb))) xor ((unsigned(wva)) and (unsigned(wvc))) xor ((unsigned(wvb)) and (unsigned(wvc))))
							);
			end if;
			stage2 <= S1;
		when others =>
			null;
	end case;
	
	case stage3 is
		when S1 =>
			if (Opcode3=LDM or Opcode3=LDR) then
				register_file(to_integer(unsigned(RX3))) <= MDR_in;
			elsif (Opcode3=LDMD) then
				mvect(to_integer(unsigned(lcount)))(63 downto 32) <= MDR_in;
				MAR <= x"000" & tmpxx;
				register_file(to_integer(unsigned(RX3))) <= std_logic_vector(lcount);
			elsif (Opcode3=STM or Opcode3=STR) then
				null;
			elsif (Opcode3 = STMD) then
				register_file(to_integer(unsigned(RY3))) <= tmpyy;
			elsif (Opcode3=CALL) then
				PC <= x"000" & unsigned(M3);
			elsif (Opcode3=POP) then
				register_file(to_integer(unsigned(RX3))) <= MDR_in;
			elsif (Opcode3=RET) then
				PC <= unsigned(MDR_in);
			elsif (Opcode3=RETI) then
				PSW <= MDR_in;	MAR <= std_logic_vector(SP);	
			elsif (Opcode3=PUSH) then
				null;	
			elsif (Opcode3=SYS) then
				SP <= SP + 1;
			elsif(Opcode3 = WPAD) then
			if (to_integer(unsigned(rcount)) < 16) then
					wvh <= wvg;
					wvg <= wvf;
					wvf <= wve;
					wve <= std_logic_vector(unsigned(wvd) + unsigned(t1_val));
					wvd <= wvc;
					wvc <= wvb;
					wvb <= wva;
					wva <= std_logic_vector(unsigned(t1_val) + unsigned(t2_val));
					rcount <= std_logic_vector((unsigned(rcount)+1));
			else
				wvh <= wvg;
				wvg <= wvf;
				wvf <= wve;
				wve <= std_logic_vector(unsigned(wvd) + unsigned(t1_val));
				wvd <= wvc;
				wvc <= wvb;
				wvb <= wva;
				wva <= std_logic_vector(unsigned(t1_val) + unsigned(t2_val));
				mvect(0) <= mvect(1);
				mvect(1) <= mvect(2);
				mvect(2) <= mvect(3);
				mvect(3) <= mvect(4);
				mvect(4) <= mvect(5);
				mvect(5) <= mvect(6);
				mvect(6) <= mvect(7);
				mvect(7) <= (mvect(8));
				mvect(8) <= (mvect(9));
				mvect(9) <= (mvect(10));
				mvect(10) <= (mvect(11));
				mvect(11) <= (mvect(12));
				mvect(12) <= (mvect(13));
				mvect(13) <= (mvect(14));
				mvect(14) <= (mvect(15));	
				mvect(15) <= wout;
				rcount <= std_logic_vector((unsigned(rcount)+1));
			end if;
			end if;
			stage3 <= S2;
		when S2 =>
			if (Opcode3=RETI) then
				MDR_in <= MEM_IN;	sp <= sp - 1;
			elsif (Opcode3=SYS) then
				MAR <= std_logic_vector(SP);
				MDR_out <= PSW;
			elsif(Opcode3 = LDMD) then
			MDR_in <= MEM_in;
			elsif(Opcode3 = STMD) then
			MAR <= tmpyy;	
			MDR_out	<= dvect(to_integer(unsigned(scount)))(31 downto 0);
			elsif (Opcode3 = WPAD) then
				if (to_integer(unsigned(rcount)) < 1) then
				 h0       <= H0_INIT;
				 h1       <= H1_INIT;
				 h2       <= H2_INIT;
				 h3       <= H3_INIT;
				 h4       <= H4_INIT;
				 h5       <= H5_INIT;
				 h6       <= H6_INIT;
				 h7       <= H7_INIT;
				 wva      <= H0_INIT;
				 wvb      <= H1_INIT;
				 wvc      <= H2_INIT;
				 wvd      <= H3_INIT;
				 wve      <= H4_INIT;
				 wvf      <= H5_INIT;
				 wvg      <= H6_INIT;
				 wvh  	 <= H7_INIT;
				end if;
				if (to_integer(unsigned(rcount)) < 16) then
				wout <= std_logic_vector(mvect(to_integer(unsigned(rcount))));
				else 
				wout <= std_Logic_vector(
						unsigned(unsigned(rotate_right(unsigned(mvect(14)),19)) xor unsigned(rotate_right(unsigned(mvect(14)),61)) xor unsigned(shift_right(unsigned(mvect(14)),6))) +
						unsigned(mvect(9)) +
						unsigned(unsigned(rotate_right(unsigned(mvect(1)),1)) xor unsigned(rotate_right(unsigned(mvect(1)),8)) xor unsigned(shift_right(unsigned(mvect(1)),7))) +
						unsigned(mvect(0)));
				end if;
			end if;
			stage3 <= S1;
		when others =>
			null;
	end case;
	
	case stage4 is
		when S1 =>
			if (Opcode4=RETI) then
				PC <= unsigned(MDR_in);
			elsif (Opcode4=SYS) then
				PC <= X"000FFC0"&unsigned(IR4(3 downto 0));
			elsif (Opcode4 = LDMD) then
				mvect(to_integer(unsigned(lcount)))(31 downto 0) <= MDR_in;
			elsif (Opcode4 = STMD) then
			null;
			elsif (Opcode4 = WPAD) then
			t1_val <= std_logic_vector(
							(unsigned(wvh) + 
							(unsigned(rotate_right(unsigned(wve), 14)) xor unsigned(rotate_right(unsigned(wve), 18)) xor unsigned(rotate_right(unsigned(wve), 41))) +
							((unsigned(wve) and unsigned(wvf)) xor (not(unsigned(wve)) and unsigned(wvg))) +
							(unsigned(K_TABLE(to_integer(unsigned(rcount)))) + unsigned(wout))
							));	
			t2_val <= std_logic_vector(
							(unsigned(rotate_right(unsigned(wva), 28)) xor unsigned(rotate_right(unsigned(wva), 34)) xor unsigned(rotate_right(unsigned(wva), 39))) +
							(((unsigned(wva)) and (unsigned(wvb))) xor ((unsigned(wva)) and (unsigned(wvc))) xor ((unsigned(wvb)) and (unsigned(wvc))))
							);
			else	stage4 <= S2;
			end if;
			stage4 <= S2;
		when S2 =>
			if (Opcode4 = LDMD) then
			lcount <= std_logic_vector(unsigned(lcount)+1);
			elsif (Opcode4 = STMD) then
			if (to_integer(unsigned(scount)) = 7) then
			scount <= x"00000000";
			else
			scount <= std_logic_vector(unsigned(scount) + 1);
			end if;
		elsif(Opcode4 = WPAD) then
			if (to_integer(unsigned(rcount)) < 16) then
					wvh <= wvg;
					wvg <= wvf;
					wvf <= wve;
					wve <= std_logic_vector(unsigned(wvd) + unsigned(t1_val));
					wvd <= wvc;
					wvc <= wvb;
					wvb <= wva;
					wva <= std_logic_vector(unsigned(t1_val) + unsigned(t2_val));
					rcount <= std_logic_vector((unsigned(rcount)+1));
			else
				wvh <= wvg;
				wvg <= wvf;
				wvf <= wve;
				wve <= std_logic_vector(unsigned(wvd) + unsigned(t1_val));
				wvd <= wvc;
				wvc <= wvb;
				wvb <= wva;
				wva <= std_logic_vector(unsigned(t1_val) + unsigned(t2_val));
				mvect(0) <= mvect(1);
				mvect(1) <= mvect(2);
				mvect(2) <= mvect(3);
				mvect(3) <= mvect(4);
				mvect(4) <= mvect(5);
				mvect(5) <= mvect(6);
				mvect(6) <= mvect(7);
				mvect(7) <= (mvect(8));
				mvect(8) <= (mvect(9));
				mvect(9) <= (mvect(10));
				mvect(10) <= (mvect(11));
				mvect(11) <= (mvect(12));
				mvect(12) <= (mvect(13));
				mvect(13) <= (mvect(14));
				mvect(14) <= (mvect(15));	
				mvect(15) <= wout;
				rcount <= std_logic_vector((unsigned(rcount)+1));
			end if;
			end if;
		stage4 <= S1;
	
		when others =>
			null;
	end case;
end if;
end process;
--------------------ALU----------------------------			
Rhody_ALU: entity work.alu port map(
		alu_op => IR2(28 downto 26), 
		operand0 => operand0, 
		operand1 => operand1,
		n => IR2(4 downto 0), 
		alu_out => ALU_out,
		carry => carry,
		overflow => overflow);	
zero <= '1' when alu_out = X"00000000" else '0';	
operand0 <= register_file(to_integer(unsigned(RX2)));
-----------------------------------------------------
end Structural;
