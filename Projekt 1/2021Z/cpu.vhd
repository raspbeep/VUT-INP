-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
-- Faculty of Information Technology
-- Author(s): Pavel Kratochvil (xkrato61)
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
-- ----------------------------------------------------------------------------
-- Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
	port (
		CLK   : in std_logic; -- hodinovy signal
		RESET : in std_logic; -- asynchronni reset procesoru
		EN    : in std_logic; -- povoleni cinnosti procesoru
		-- synchronni pamet ROM
		CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
		CODE_DATA : in std_logic_vector(7 downto 0); -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
		CODE_EN   : out std_logic; -- povoleni cinnosti
		-- synchronni pamet RAM
		DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
		DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
		DATA_RDATA : in std_logic_vector(7 downto 0); -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
		DATA_WREN  : out std_logic; -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
		DATA_EN    : out std_logic; -- povoleni cinnosti
		-- vstupni port
		IN_DATA : in std_logic_vector(7 downto 0); -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
		IN_VLD  : in std_logic; -- data platna pokud IN_VLD='1'
		IN_REQ  : out std_logic; -- pozadavek na vstup dat z klavesnice
		-- vystupni port
		OUT_DATA : out std_logic_vector(7 downto 0); -- zapisovana data
		OUT_BUSY : in std_logic; -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat, OUT_WREN musi byt '0'
		OUT_WREN : out std_logic -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
	);
end cpu;
-- ----------------------------------------------------------------------------
-- Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
	--- PC ---
	signal pc_reg : std_logic_vector (11 downto 0);
	signal pc_inc : std_logic;
	signal pc_dec : std_logic;
	--- PC
	--- PTR ---
	signal ptr_reg : std_logic_vector(9 downto 0);
	signal ptr_inc : std_logic;
	signal ptr_dec : std_logic;
	--- PTR ---
	--- CNT ---
	signal cnt_reg : std_logic_vector (11 downto 0);
	signal cnt_inc : std_logic;
	signal cnt_dec : std_logic;
	--- CNT ---
	-- STATES ---
		type fsm_state is (
			s_start, -- startovaci stav
			
			s_fetch_0, -- nacitanie instrukcie, nastavenie stavu
			s_fetch_1,
			
			s_decode, -- dekodovanie instrukcie
			
			s_ptr_inc, -- > inkrementacia hodnoty ukazatela
			s_ptr_dec, -- < dekrementacia hodnoty ukazatela
			
			s_ptr_mem_inc_0, -- + inkrementacia aktualnej bunky
			s_ptr_mem_inc_1,
			s_ptr_mem_inc_2,

			s_ptr_mem_dec_0, -- - dekrementacia aktualnej bunky
			s_ptr_mem_dec_1,
			s_ptr_mem_dec_2,

			s_while_0, -- [ while cyklus
			s_while_1,
			s_while_2,
			s_while_3,
			s_while_4,


			s_while_end_0, -- ] ukoncenie while cyklu
			s_while_end_1,
			s_while_end_2,
			s_while_end_3,
			s_while_end_4,
			s_while_end_5,
			s_while_end_delay,

			s_putchar_0, -- . vytlacenie hodnoty aktualnej bunky
			s_putchar_1,

			s_break_0, -- ~ break, vyskocenie z while cyklu
			s_break_1,
			s_break_2,

			s_stop, -- null ukonci aktualny while
			
			s_read_0, -- , nacitanie z klavesnice
			s_read_1,
			s_read_2,
			
			s_comment
			);
	-- STATES ---
	
	-- STATE SIGNALS---
		signal fsm_current_state : fsm_state := s_start;
		signal fsm_next_state    : fsm_state;
	-- STATE SIGNALS---
	
	-- MULTIPLEXOR SIGNALS ---
		signal mux_select : std_logic_vector(1 downto 0) := (others => '0');
		signal mux_output : std_logic_vector(7 downto 0) := (others => '0');
	-- MULTIPLEXOR ---
begin
	--- PROGRAM COUNTER ---
		pc_cntr : process (CLK, RESET, pc_inc, pc_dec, pc_reg)
		begin
			if RESET = '1' then
				pc_reg <= (others => '0'); -- in/dekrement aktualneho ukazatela na prave vykonavanu instrukciu
			elsif CLK'EVENT and CLK = '1' then
				if pc_inc = '1' then
					pc_reg <= pc_reg + 1;
				elsif pc_dec = '1' then
					pc_reg <= pc_reg - 1;
				end if;
			end if;
		end process;
		CODE_ADDR <= pc_reg;
	--- PROGRAM COUNTER ---
	--- MEMORY POINTER ---
		mem_ptr : process (CLK, RESET, ptr_inc, ptr_dec, ptr_reg)
		begin
			if RESET = '1' then
				ptr_reg <= (others => '0');
			elsif CLK'EVENT and CLK = '1' then -- in/dekrement aktualneho ukazatela do ram
				if ptr_inc = '1' then
					ptr_reg <= ptr_reg + 1;
				elsif ptr_dec = '1' then
					ptr_reg <= ptr_reg - 1;
				end if;
			end if;
		end process;
		DATA_ADDR <= ptr_reg;
	--- MEMORY POINTER ---
	--- WHILE COUNTER ---
		cnt_cntr : process (CLK, RESET, cnt_inc, cnt_dec, cnt_reg)
		begin
			if RESET = '1' then
				cnt_reg <= (others => '0');
			elsif CLK'EVENT and CLK = '1' then	-- in/dekrement hodnoty registra na pocitanie while cyklov
				if cnt_inc = '1' then
					cnt_reg <= cnt_reg + 1;
				elsif cnt_dec = '1' then
					cnt_reg <= cnt_reg - 1;
				end if;
			end if;
		end process;
		DATA_ADDR <= ptr_reg;
	--- WHILE COUNTER ---
	--- MULTIPLEXOR ---
		mux : process (CLK, RESET, mux_select, IN_DATA, DATA_RDATA)
		begin
			if RESET = '1' then
				mux_output <= (others => '0');
			elsif (CLK'EVENT and CLK = '1') then
				case mux_select is
					when "00" => mux_output <= IN_DATA;   			-- vyber vstupu ktory sa ma zapisat do ram. bud je to z IN_DATA alebo je to in/dekrement z ram
					when "01" => mux_output <= DATA_RDATA - 1;
					when "10" => mux_output <= DATA_RDATA + 1;
					when others => mux_output    <= (others => '0');
				end case;
			end if;
		end process;
		DATA_WDATA <= mux_output;
		OUT_DATA   <= DATA_RDATA;
	--- MULTIPLEXOR ---
	--- FSM NEXT STATE LOGIC ---
		next_state_logic : process (CLK, RESET, EN)
		begin
			if RESET = '1' then -- prepne fsm do dalsieho stavu okrem casu kedy je zapnuty reset procesora
				fsm_current_state <= s_start;
			elsif (CLK'event) and (CLK = '1') and (EN = '1') then
				fsm_current_state <= fsm_next_state;
			end if;
		end process;
	--- FSM NEXT STATE LOGIC ---

	--- FSM ---
		fsm : process (fsm_current_state, RESET, CODE_DATA, IN_VLD, OUT_BUSY, DATA_RDATA, cnt_reg, CODE_DATA)
		begin
			-- INICIALIZACIA -- nulovanie vsetkych signalov aktivovanych v predoslom clocku
			DATA_WREN  <= '0';
			IN_REQ     <= '0';
			CODE_EN    <= '0';
			pc_inc     <= '0';
			pc_dec     <= '0';
			cnt_inc    <= '0';
			cnt_dec    <= '0';
			ptr_inc    <= '0';
			ptr_dec    <= '0';
			mux_select <= "00";
			OUT_WREN   <= '0';
			DATA_EN    <= '0';
			
			if RESET = '1' then
				fsm_next_state <= s_start;
			else
				case fsm_current_state is
					when s_start =>
						fsm_next_state <= s_fetch_0; -- pociatocny stav fsm
						
					when s_fetch_0 =>
						CODE_EN        <= '1'; -- obnovenie hodnoty citanej z rom
						fsm_next_state <= s_fetch_1;
						
					when s_fetch_1 => -- oneskorenie aby dekodovana hodnota bola korektna
						fsm_next_state <= s_decode;
						
					when s_decode =>

						case CODE_DATA is -- vyber dalsieho stavu na zaklade nacitanej instrukcie z CODE_DATA z rom
						-- > --
							when X"3E" =>
								fsm_next_state <= s_ptr_inc;
						-- < --
							when X"3C" =>
								fsm_next_state <= s_ptr_dec;
						-- + --
							when X"2B" =>
								fsm_next_state <= s_ptr_mem_inc_0;
						-- , --
							when X"2C" =>
								fsm_next_state <= s_read_0;
						-- - --
							when X"2D" =>
								fsm_next_state <= s_ptr_mem_dec_0;
						-- [ --
							when X"5B" =>
								fsm_next_state <= s_while_0;
						-- ] --
							when X"5D" =>
								fsm_next_state <= s_while_end_0;
						-- . --
							when X"2E" =>
								fsm_next_state <= s_putchar_0;
						-- ~ --
							when X"7E" =>
								fsm_next_state <= s_break_0;
						-- ~ --
							when X"00" =>
								fsm_next_state <= s_stop;
						-- others --
							when others =>
								fsm_next_state <= s_comment;
					end case;
				--- > ---
					when s_ptr_inc =>
						ptr_inc        <= '1'; -- zvysenie ukazatela do ram
						pc_inc         <= '1';
						fsm_next_state <= s_fetch_0;
				--- > ---
				--- < ---
					when s_ptr_dec =>
						ptr_dec        <= '1'; -- znizenie ukazatela do ram
						pc_inc         <= '1';
						fsm_next_state <= s_fetch_0;
				--- < ---
				--- + ---
					when s_ptr_mem_inc_0 =>
						DATA_EN        <= '1'; -- nacitanie hodnoty z ram
						DATA_WREN      <= '0';
						fsm_next_state <= s_ptr_mem_inc_1;
						
					when s_ptr_mem_inc_1 =>
						mux_select     <= "10"; -- prepnutie na inkrement hodnoty z ram
						fsm_next_state <= s_ptr_mem_inc_2;
						
					when s_ptr_mem_inc_2 =>
						DATA_EN        <= '1'; -- zapis inkrementovanej hodnoty z ram do ram
						DATA_WREN      <= '1';
						pc_inc         <= '1';
						fsm_next_state <= s_fetch_0;
				--- + ---
				--- - ---
					when s_ptr_mem_dec_0 =>
						DATA_EN        <= '1';	-- nacitanie hodnoty z ram
						DATA_WREN      <= '0';
						fsm_next_state <= s_ptr_mem_dec_1;
						
					when s_ptr_mem_dec_1 =>
						mux_select     <= "01"; -- prepnutie na dekrement hodnoty z ram
						fsm_next_state <= s_ptr_mem_dec_2;
						
					when s_ptr_mem_dec_2 =>
						DATA_EN        <= '1'; -- zapis dekrementovanej hodnoty z ram do ram
						DATA_WREN      <= '1';
						pc_inc         <= '1';
						fsm_next_state <= s_fetch_0;
				--- - ---
				--- . ---
					when s_putchar_0 =>
						DATA_EN        <= '1';	-- zapnutie citania z ram a obnovenie DATA_RDATA
						DATA_WREN      <= '0';
						fsm_next_state <= s_putchar_1;

					when s_putchar_1 =>
						if OUT_BUSY = '1' then -- kym nebude deisplay pripraveny na vypis tak opakuj tento stav
							DATA_EN        <= '1';
							DATA_WREN      <= '0';
							fsm_next_state <= s_putchar_1;
						else
							OUT_WREN <= '1'; -- inak zapis obnovenu hodnotu z ram na display
							pc_inc         <= '1';
							fsm_next_state <= s_fetch_0;
						end if;
				--- . ---
				--- [ ---
					when s_while_0 =>
						DATA_EN        <= '1';
						DATA_WREN      <= '0';
						pc_inc         <= '1';
						fsm_next_state <= s_while_1;
						
					when s_while_1 =>
						if (DATA_RDATA = "00000000") then -- ak je hodnota aktualnej bunky=0 tak skip
							cnt_inc        <= '1';	-- inkrement countra, kym nebude counter=0 tak skipuj
							fsm_next_state <= s_while_2;
						else
							fsm_next_state <= s_fetch_0;
						end if;

					when s_while_2 =>
						if (cnt_reg = "000000000000") then	-- ak mas nulu tak pokracuj dalsou instrukciou
							fsm_next_state <= s_fetch_0;
						else											-- kym nemas nulu tak skipuj
							CODE_EN        <= '1';
							fsm_next_state <= s_while_3;		-- delay state
						end if;
						
					when s_while_3 =>
						
						fsm_next_state <= s_while_4;
						
					when s_while_4 =>
						if (CODE_DATA = X"5B") then	-- otvaracia zatvorka
							cnt_inc        <= '1';		-- inkrement, musim k nej najst par
							fsm_next_state <= s_while_2;	-- pokracuj v skipovani
						elsif (CODE_DATA = X"5D") then	-- zatvaracia zatvorka
							cnt_dec        <= '1';			-- dekrement, nasiel som par k predoslej
							fsm_next_state <= s_while_2;
						end if;
						pc_inc         <= '1';
						fsm_next_state <= s_while_2;
				--- [ ---
				--- ] ---
					when s_while_end_0 =>
						DATA_EN        <= '1';
						DATA_WREN      <= '0';
						fsm_next_state <= s_while_end_1;
						
					when s_while_end_1 =>
						if (DATA_RDATA = "00000000") then	-- ak je aktualna nula, pokracuj dalsim prikazom
							pc_inc         <= '1';
							fsm_next_state <= s_fetch_0;
						else
							fsm_next_state <= s_while_end_2;	-- inak sa vrat k odpovedajucej otvaracej zatvorke
						end if;
						
					when s_while_end_2 =>
						cnt_inc        <= '1';
						pc_dec         <= '1';
						fsm_next_state <= s_while_end_3;
						
					when s_while_end_3 =>
						if (cnt_reg = "000000000000") then -- ak mam prazdny cnt_reg, vysiel som so vsetkych while cyklov, pokracujem s fetch
							fsm_next_state <= s_fetch_0;
						else
							fsm_next_state <= s_while_end_delay;
						end if;
						
					when s_while_end_delay =>	-- delay na nacitanie dalsieho znaku
						CODE_EN        <= '1';
						fsm_next_state <= s_while_end_4;
						
					when s_while_end_4 =>
						if (CODE_DATA = X"5D") then -- zatvaracia zatvorka pri vracani sa, pricitam cnt_inc
							cnt_inc        <= '1';
							fsm_next_state <= s_while_end_5;
						elsif (CODE_DATA = X"5B") then -- otvaracia zatvorka pri vracani sa, odcitam cnt_dec
							cnt_dec        <= '1';
							fsm_next_state <= s_while_end_5;
						end if;
						fsm_next_state <= s_while_end_5;
						
					when s_while_end_5 =>
						if (cnt_reg = "000000000000") then	-- ak mam nulovy cnt_reg, vysiel som zo vsetkych cyklov, cez delay sa dostanem do fetch
							pc_inc         <= '1';
							fsm_next_state <= s_while_end_3;
						else
							pc_dec         <= '1';
							fsm_next_state <= s_while_end_3;
						end if;
				--- ] ---
				--- ~ ---
					when s_break_0 =>
						pc_inc         <= '1';
						cnt_inc        <= '1';
						fsm_next_state <= s_break_1;
						
					when s_break_1 =>
						if (cnt_reg = "000000000000") then	-- ked pridem do stavu vyskocenia z prislusneho cyklu, pokracujem na fetch
							fsm_next_state <= s_fetch_0;
						else
							fsm_next_state <= s_break_2;	-- inak skipujem v s_break_2
							CODE_EN        <= '1';
						end if;
					when s_break_2 =>
					
						if (CODE_DATA = X"5B") then	-- ak mam otvaraciu, vstupil som do dalsieho cyklu, pricitam cnt_inc
							cnt_inc        <= '1';
							fsm_next_state <= s_break_1;
						elsif (CODE_DATA = X"5D") then	-- ak mam zatvaraciu, vyskocil som z nejakeho while cyklu, odcitam
							cnt_dec        <= '1';
							fsm_next_state <= s_break_1;
						end if;
						pc_inc         <= '1';
						fsm_next_state <= s_break_1;
				--- ~ ---
				--- , ---
					when s_read_0 =>	
						IN_REQ <= '1'; -- zapnutie ziadosti o citanie z klavesnice
						mux_select <= "00";
						fsm_next_state <= s_read_1;
					
					when s_read_1 =>
						if (IN_VLD = '0') then	-- kym nemam in_vld, opakujem cyklus
							IN_REQ <= '1';
							mux_select <= "00";
							fsm_next_state <= s_read_1;
							
						else
							mux_select <= "00";	-- prepnutie multiplexora na zapis z IN_DATA
							
							fsm_next_state <= s_read_2;
							
						end if;
						
					when s_read_2 =>
						DATA_EN <= '1';	-- zapis z klavesnice do ram
						DATA_WREN <= '1';
						pc_inc <= '1';
						fsm_next_state <= s_fetch_0;
				--- , ---
				--- stop ---
				when s_stop =>
					fsm_next_state <= s_stop;
				--- stop ---
				--- others ---
					when s_comment =>
						pc_inc         <= '1'; -- stav pre komentar, neznamy znak, pokracujem dalsou instrukciou
						fsm_next_state <= s_fetch_0;
					when others =>	
						fsm_next_state <= s_start;
				--- others ---
				end case;
			end if;
		end process;
	--- FSM ---
end behavioral;
