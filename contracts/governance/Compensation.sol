/* Network activiies that receive compentation in CPY:
 * - Creating new proposed experiences
 * - Rendering experiences for users
 * - Staking tokens as a network keeper
 *
 * Compensation can come from:
 * - Existing CPY in the treasury
 * - CPY contributed by holders
 * - CPY minted via vote
 */
enum COMPENSATABLE_ACTION = { PROPOSAL, RENDER, STAKED }
enum COMPENSATION_TYPE = { MINT, TREASURY, CONTRIB }
