Ecmascript file had an error
./app/api/crm/deals/analytics/leaderboard/route.ts (189:23)

Ecmascript file had an error
  187 |  * Returns leaderboard data grouped by user/rep
  188 |  */
> 189 | export async function GET(request: NextRequest) {
      |                       ^^^
  190 |   try {
  191 |     // Authenticate user
  192 |     const cookieStore = await cookies()

the name `GET` is defined multiple times