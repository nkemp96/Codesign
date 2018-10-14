library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity CalcTotalDistance is
   port( 
      Clk: in  std_logic;
      RESET: in std_logic;
      start: in std_logic;
      ready: out std_logic;
      PNL_BRAM_addr: out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
      PNL_BRAM_din: out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
      PNL_BRAM_dout: in std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
      PNL_BRAM_we: out std_logic_vector(0 to 0)
      );
end CalcTotalDistance;

architecture beh of CalcTotalDistance is
   type state_type is (idle, get_point_addr, get_cluster_addr, get_p1_val, get_p2_val, get_dist, get_sqr, sum_dist);
   signal state_reg, state_next: state_type;

   signal ready_reg, ready_next: std_logic;

-- Address registers for the PNs and Kmeans data  portions of memory
   signal PN_addr_reg, PN_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal centroids_addr_reg, centroids_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   
-- for iterating through # of points and #cluster
   signal dist_addr_reg, dist_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal dist_count_reg, dist_count_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);
   signal cluster_val_reg, cluster_val_next:  unsigned(3 downto 0);
   signal num_dims_reg, num_dims_next: unsigned(3 downto 0);
   
   signal received : std_logic;
-- For selecting between PN or CalcTotalDistance portion of memory during memory accesses
   signal do_PN_dist_addr: std_logic;

-- Stores the full 16-bit distance 
   signal distance_val_reg, distance_val_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal dist_sqr_reg, dist_sqr_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal p1_val_reg, p1_val_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal p2_val_reg, p2_val_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal num_vals_reg, num_vals_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal num_clusters_reg, num_clusters_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
   signal num_dims_reg, num_dims_next: signed(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	
-- These are 12 bits each to hold only the 12-bit integer portion of the PNs
   signal shifted_dout: signed(PN_INTEGER_NB-1 downto 0);
   signal shifted_distance_val: signed(PN_INTEGER_NB-1 downto 0);

   begin

-- =============================================================================================
-- State and register logic
-- =============================================================================================
   process(Clk, RESET)
      begin
      if ( RESET = '1' ) then
         state_reg <= idle;
         ready_reg <= '1';
         PN_addr_reg <= (others => '0');
         points_addr_reg <= (others => '0');
	 centroids_addr_reg <= (others => '0');
	 num_vals_reg <= (others => '0');
	 num_clusters_reg <= (others => '0');
	 num_dims_reg <= (others => '0');
         distance_val_reg <= (others => '0');
	 cluster_val_reg <= (others => '0');
	 num_dims_reg <= (others => '0');
	 dist_count_reg <= (others => '0');
	 dist_sqr_reg <= (others => '0');
      elsif ( Clk'event and Clk = '1' ) then
         state_reg <= state_next;
         ready_reg <= ready_next;
         PN_addr_reg <= PN_addr_next;
         points_addr_reg <= points_addr_next;
	 cluster_val_reg <= cluster_val_next;
	 centroids_addr_reg <= centroids_addr_next;
	 num_vals_reg <= num_vals_next;
	 num_clusters_reg <= num_clusters_next;
	 num_dims_reg <= num_dims_next;
         distance_val_reg <= distance_val_next;
	 num_dims_reg <= num_dims_next;
	 dist_count_reg <= dist_count_next;
	 dist_sqr_reg <= dist_sqr_next;
      end if; 
   end process;


-- =============================================================================================
-- Combo logic
-- =============================================================================================

   process (state_reg, start, ready_reg, points_addr_reg, centroids_addr_reg, cluster_val_reg, dist_addr_reg, PNL_BRAM_dout)
      begin
      state_next <= state_reg;
      ready_next <= ready_reg;

      PN_addr_next <= PN_addr_reg;
      points_addr_next <= points_addr_reg;
      centroids_addr_next <= centroids_addr_reg;
      dist_addr_next <= dist_addr_reg;
      distance_val_next <= distance_val_reg;
      cluster_val_next <= cluster_val_reg;
      num_dims_next <= num_dims_reg;
      dist_sqr_next <= dist_sqr_reg;
      dist_count_next <= dist_count_reg;
      num_vals_next <= num_vals_reg;
      num_clusters_next <= num_clusters_next;
      num_dims_next <= num_dims_reg;

-- Default value is 0 -- used during memory initialization.
      PNL_BRAM_din <= (others=>'0');
      PNL_BRAM_we <= "0";

      do_PN_dist_addr <= '0';

      case state_reg is

-- =====================
         when idle =>
            ready_next <= '1';

            if ( start = '1' ) then
               ready_next <= '0';



-- Zero the register that will store distances
               distance_val_next <= (others=>'0');

-- Allow CalcAllDist_addr to drive PNL_BRAM
               do_PN_dist_addr <= '1';

	       dist_addr_next <= (others=>'0');
	       cluster_val_next <= (others=>'0');
	       distance_val_next <= (others=> '0');
	       dist_sqr_next <= (others => '0');
	       dist_count_next <= (others => '0');
               centroids_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
	       points_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
	       PN_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
               state_next <= get_prog_addr;
            end if;
			
         when get_point_addr =>
			
	    if ( dist_count_reg = num_vals_reg - 1 ) then
	       state_next <= idle;
			
	    else
	       points_addr_next <= to_unsigned(PN_BRAM_BASE,PNL_BRAM_ADDR_SIZE_NB) + (dist_count_reg * NUM_DIMS) + PROG_VALS;
	       state_next <= get_cluster_addr;
			
			
-- =====================
-- get bram address of current centroid.
         when get_cluster_addr =>
	    if(cluster_val_reg = num_clusters_reg -1) then
	       cluster_val_next <= others=>'0');
	       dist_count_next <= dist_count_reg +1;
	       state_next <= get_point_addr;
	    else
	       centroids_addr_next <= to_unsigned(PN_BRAM_BASE,PNL_BRAM_ADDR_SIZE_NB )
				      + (cluster_val_reg * num_dims_reg) + (num_vals_reg * num_dims_reg) + PROG_VALS ;
	       start_calcDistance <= '1';
	       PN_addr_next <= points_addr_reg;
	       state_next <= get_lower_val;
	    end if;      
-- get p1 value
	 when get_p1_addr =>
               PN_addr_next <= centroids_addr_reg;
               state_next <= get_p1_val;

	 when get_p1_val =>
	    if(num_dims_reg= num_dims_reg-1)
	       do_PN_disy_addr <= '1';
	       PNL_BRAM_din <= distance_val_reg;	
	       PNL_BRAM_we <= "1";		
	       dist_addr_next <= to_unsigned(KMEANS_DIST_BASE_ADDR,PNL_BRAM_ADDR_SIZE_NB) 
				 +  ((dist_count_reg * num_clusters_reg)+ cluster_val_reg);
	       cluster_val_next <= cluster_val_reg +1;
	       state_next <= get_cluster_addr;
	 		 
	    else
	       p1_val_next <= signed(PNL_BRAM_dout);
	       PN_addr_next <= centroids_addr_reg;
	       state_next <= get_p2_addr;
            end if;
			
	 when get_p2_addr =>
	       PN_addr_next <= centroids_addr_reg;
	       state_next <= get_p2_val;
			
			
	 when get_p2_val =>
	       p2_val_next <= signed(PNL_BRAM_dout);
	       PN_addr_next <= centroids_addr_reg;
	       state_next <= get_dist;
			
	 when get_dist =>
	       distance_val_next <= signed(p1_val_reg - p1_val_reg);
	       state_next <= get_sqr;

         when get_sqr =>
	       dist_sqr_next <= signed(distance_val_reg * distance_val_reg);
	       state_next <= sum_dist;
			
	 when sum_dist =>
	       distance_val_next <= distance_val_reg + dist_sqr_reg;
	       state_next <= get_p1_val;
      end case;
   end process;	
			

-- Using _reg here (not the look-ahead _next value).
   with do_PN_dist_addr select
      PNL_BRAM_addr <= std_logic_vector(PN_addr_next) when '0',
                       std_logic_vector(dist_addr_next) when others;

   CalcAllDist_ERR <= CalcAllDist_ERR_reg;
   ready <= ready_reg;

end beh;