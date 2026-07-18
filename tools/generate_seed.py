#!/usr/bin/env python3
"""ToneAmp seed catalog generator.

Input: hand-authored song lines  Title|Artist|Year|Genre|Character
Genres: R Rock, HR Hard Rock, M Metal, G Grunge, B Blues Rock,
        A Alternative, F Funk Rock, P Psychedelic, T Anadolu Rock
Characters: CL Clean, CR Crunch, OD Overdrive, HG High Gain, FZ Fuzz, LD Lead

For each song: derives era/genre-appropriate amp, settings (deterministic
jitter from a hash so output is stable), guitar/pickup, pedal chain; then
canonicalizes against the iTunes Search API (title/album/artwork).
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

SONGS = """
# ============ ENGLISH / INTERNATIONAL ============
Smoke on the Water|Deep Purple|1972|HR|CR
Highway Star|Deep Purple|1972|HR|LD
Child in Time|Deep Purple|1970|HR|OD
Burn|Deep Purple|1974|HR|CR
Black Night|Deep Purple|1970|HR|CR
Perfect Strangers|Deep Purple|1984|HR|CR
Lazy|Deep Purple|1972|HR|OD
Space Truckin'|Deep Purple|1972|HR|CR
Whole Lotta Love|Led Zeppelin|1969|HR|CR
Stairway to Heaven|Led Zeppelin|1971|R|LD
Kashmir|Led Zeppelin|1975|HR|CR
Black Dog|Led Zeppelin|1971|HR|CR
Rock and Roll|Led Zeppelin|1971|HR|CR
Immigrant Song|Led Zeppelin|1970|HR|CR
Good Times Bad Times|Led Zeppelin|1969|HR|CR
Ramble On|Led Zeppelin|1969|R|CL
Since I've Been Loving You|Led Zeppelin|1970|B|OD
Heartbreaker|Led Zeppelin|1969|HR|CR
Communication Breakdown|Led Zeppelin|1969|HR|CR
Over the Hills and Far Away|Led Zeppelin|1973|R|CL
The Ocean|Led Zeppelin|1973|HR|CR
Dazed and Confused|Led Zeppelin|1969|P|OD
Ten Years Gone|Led Zeppelin|1975|R|OD
Achilles Last Stand|Led Zeppelin|1976|HR|CR
In My Time of Dying|Led Zeppelin|1975|B|OD
Babe I'm Gonna Leave You|Led Zeppelin|1969|R|CL
Comfortably Numb|Pink Floyd|1979|R|LD
Another Brick in the Wall Part 2|Pink Floyd|1979|R|CL
Money|Pink Floyd|1973|R|OD
Time|Pink Floyd|1973|R|LD
Shine On You Crazy Diamond|Pink Floyd|1975|R|LD
Wish You Were Here|Pink Floyd|1975|R|CL
Have a Cigar|Pink Floyd|1975|R|CR
Hey You|Pink Floyd|1979|R|CL
Run Like Hell|Pink Floyd|1979|R|CL
Dogs|Pink Floyd|1977|R|OD
Breathe|Pink Floyd|1973|R|CL
Young Lust|Pink Floyd|1979|HR|CR
Purple Haze|Jimi Hendrix|1967|P|FZ
Voodoo Child (Slight Return)|Jimi Hendrix|1968|P|FZ
Little Wing|Jimi Hendrix|1967|P|CL
Hey Joe|Jimi Hendrix|1966|P|OD
All Along the Watchtower|Jimi Hendrix|1968|P|OD
Foxey Lady|Jimi Hendrix|1967|P|FZ
Fire|Jimi Hendrix|1967|P|OD
The Wind Cries Mary|Jimi Hendrix|1967|P|CL
Crosstown Traffic|Jimi Hendrix|1968|P|FZ
Red House|Jimi Hendrix|1967|B|OD
Sunshine of Your Love|Cream|1967|P|FZ
White Room|Cream|1968|P|FZ
Crossroads|Cream|1968|B|OD
Badge|Cream|1969|R|CL
Strange Brew|Cream|1967|B|OD
My Generation|The Who|1965|R|CR
Baba O'Riley|The Who|1971|R|CR
Won't Get Fooled Again|The Who|1971|HR|CR
Pinball Wizard|The Who|1969|R|CL
Behind Blue Eyes|The Who|1971|R|CL
Substitute|The Who|1966|R|CR
I Can See for Miles|The Who|1967|P|CR
Who Are You|The Who|1978|R|CR
The Seeker|The Who|1970|R|CR
Love Reign O'er Me|The Who|1973|R|CR
You Really Got Me|The Kinks|1964|R|CR
All Day and All of the Night|The Kinks|1964|R|CR
Waterloo Sunset|The Kinks|1967|R|CL
Lola|The Kinks|1970|R|CL
Sunny Afternoon|The Kinks|1966|R|CL
Day Tripper|The Beatles|1965|R|CR
Come Together|The Beatles|1969|R|CL
While My Guitar Gently Weeps|The Beatles|1968|R|OD
Helter Skelter|The Beatles|1968|HR|FZ
Get Back|The Beatles|1969|R|CL
Let It Be|The Beatles|1970|R|OD
Hey Bulldog|The Beatles|1968|R|CR
Taxman|The Beatles|1966|R|CR
Paperback Writer|The Beatles|1966|R|CR
Revolution|The Beatles|1968|R|FZ
Something|The Beatles|1969|R|CL
Ticket to Ride|The Beatles|1965|R|CL
A Hard Day's Night|The Beatles|1964|R|CL
I Want You (She's So Heavy)|The Beatles|1969|R|OD
Oh! Darling|The Beatles|1969|R|OD
(I Can't Get No) Satisfaction|The Rolling Stones|1965|R|FZ
Jumpin' Jack Flash|The Rolling Stones|1968|R|CR
Gimme Shelter|The Rolling Stones|1969|R|CL
Paint It Black|The Rolling Stones|1966|P|CL
Brown Sugar|The Rolling Stones|1971|R|CR
Start Me Up|The Rolling Stones|1981|R|CR
Sympathy for the Devil|The Rolling Stones|1968|R|CL
Honky Tonk Women|The Rolling Stones|1969|R|CR
Street Fighting Man|The Rolling Stones|1968|R|CR
Angie|The Rolling Stones|1973|R|CL
Beast of Burden|The Rolling Stones|1978|R|CL
Can't You Hear Me Knocking|The Rolling Stones|1971|R|CR
Wild Horses|The Rolling Stones|1971|R|CL
Miss You|The Rolling Stones|1978|F|CL
Tumbling Dice|The Rolling Stones|1972|R|CR
Fortunate Son|Creedence Clearwater Revival|1969|R|CR
Have You Ever Seen the Rain|Creedence Clearwater Revival|1971|R|CL
Bad Moon Rising|Creedence Clearwater Revival|1969|R|CL
Green River|Creedence Clearwater Revival|1969|R|CR
Born on the Bayou|Creedence Clearwater Revival|1969|R|CR
Proud Mary|Creedence Clearwater Revival|1969|R|CL
Up Around the Bend|Creedence Clearwater Revival|1970|R|CR
Down on the Corner|Creedence Clearwater Revival|1969|R|CL
Hotel California|Eagles|1976|R|LD
Life in the Fast Lane|Eagles|1976|R|CR
Take It Easy|Eagles|1972|R|CL
One of These Nights|Eagles|1975|R|CL
Desperado|Eagles|1973|R|CL
Already Gone|Eagles|1974|R|CR
Heartache Tonight|Eagles|1979|R|CR
Walk This Way|Aerosmith|1975|HR|CR
Sweet Emotion|Aerosmith|1975|HR|CR
Dream On|Aerosmith|1973|R|CL
Back in the Saddle|Aerosmith|1976|HR|CR
Mama Kin|Aerosmith|1973|HR|CR
Livin' on the Edge|Aerosmith|1993|HR|CR
Cryin'|Aerosmith|1993|HR|OD
Love in an Elevator|Aerosmith|1989|HR|CR
Janie's Got a Gun|Aerosmith|1989|HR|CL
Same Old Song and Dance|Aerosmith|1974|HR|CR
Last Child|Aerosmith|1976|F|CR
Toys in the Attic|Aerosmith|1975|HR|CR
Back in Black|AC/DC|1980|HR|CR
Highway to Hell|AC/DC|1979|HR|CR
Thunderstruck|AC/DC|1990|HR|CR
You Shook Me All Night Long|AC/DC|1980|HR|CR
Hells Bells|AC/DC|1980|HR|CR
Shoot to Thrill|AC/DC|1980|HR|CR
T.N.T.|AC/DC|1975|HR|CR
Dirty Deeds Done Dirt Cheap|AC/DC|1976|HR|CR
Let There Be Rock|AC/DC|1977|HR|CR
Whole Lotta Rosie|AC/DC|1977|HR|CR
For Those About to Rock|AC/DC|1981|HR|CR
Rock or Bust|AC/DC|2014|HR|CR
It's a Long Way to the Top|AC/DC|1975|HR|CR
Riff Raff|AC/DC|1978|HR|CR
Sin City|AC/DC|1978|HR|CR
Bohemian Rhapsody|Queen|1975|R|LD
We Will Rock You|Queen|1977|HR|LD
Killer Queen|Queen|1974|R|LD
Fat Bottomed Girls|Queen|1978|HR|CR
Stone Cold Crazy|Queen|1974|HR|CR
Tie Your Mother Down|Queen|1976|HR|CR
Hammer to Fall|Queen|1984|HR|CR
I Want It All|Queen|1989|HR|CR
Now I'm Here|Queen|1974|HR|CR
Brighton Rock|Queen|1974|HR|LD
Keep Yourself Alive|Queen|1973|HR|CR
One Vision|Queen|1985|HR|CR
Paranoid|Black Sabbath|1970|M|CR
Iron Man|Black Sabbath|1970|M|CR
War Pigs|Black Sabbath|1970|M|CR
Children of the Grave|Black Sabbath|1971|M|CR
N.I.B.|Black Sabbath|1970|M|CR
Sweet Leaf|Black Sabbath|1971|M|CR
Sabbath Bloody Sabbath|Black Sabbath|1973|M|CR
Snowblind|Black Sabbath|1972|M|CR
Supernaut|Black Sabbath|1972|M|CR
Heaven and Hell|Black Sabbath|1980|M|CR
Breaking the Law|Judas Priest|1980|M|HG
Painkiller|Judas Priest|1990|M|HG
Living After Midnight|Judas Priest|1980|M|CR
You've Got Another Thing Comin'|Judas Priest|1982|M|CR
Electric Eye|Judas Priest|1982|M|HG
Turbo Lover|Judas Priest|1986|M|HG
Hell Bent for Leather|Judas Priest|1978|M|CR
Victim of Changes|Judas Priest|1976|M|CR
The Trooper|Iron Maiden|1983|M|HG
Run to the Hills|Iron Maiden|1982|M|HG
The Number of the Beast|Iron Maiden|1982|M|HG
Fear of the Dark|Iron Maiden|1992|M|HG
Hallowed Be Thy Name|Iron Maiden|1982|M|HG
2 Minutes to Midnight|Iron Maiden|1984|M|HG
Aces High|Iron Maiden|1984|M|HG
Wasted Years|Iron Maiden|1986|M|HG
Powerslave|Iron Maiden|1984|M|HG
Phantom of the Opera|Iron Maiden|1980|M|HG
Wrathchild|Iron Maiden|1981|M|HG
Flight of Icarus|Iron Maiden|1983|M|HG
Can I Play with Madness|Iron Maiden|1988|M|HG
The Evil That Men Do|Iron Maiden|1988|M|HG
Ace of Spades|Motörhead|1980|M|CR
Overkill|Motörhead|1979|M|CR
Bomber|Motörhead|1979|M|CR
Killed by Death|Motörhead|1984|M|CR
Iron Fist|Motörhead|1982|M|CR
Enter Sandman|Metallica|1991|M|HG
Master of Puppets|Metallica|1986|M|HG
One|Metallica|1988|M|HG
Nothing Else Matters|Metallica|1991|M|CL
Fade to Black|Metallica|1984|M|CL
Sad but True|Metallica|1991|M|HG
For Whom the Bell Tolls|Metallica|1984|M|HG
Battery|Metallica|1986|M|HG
Creeping Death|Metallica|1984|M|HG
Seek & Destroy|Metallica|1983|M|HG
Fuel|Metallica|1997|M|HG
The Unforgiven|Metallica|1991|M|CL
Wherever I May Roam|Metallica|1991|M|HG
Whiskey in the Jar|Metallica|1998|M|CR
Welcome Home (Sanitarium)|Metallica|1986|M|CL
Ride the Lightning|Metallica|1984|M|HG
Blackened|Metallica|1988|M|HG
Moth Into Flame|Metallica|2016|M|HG
Atlas, Rise!|Metallica|2016|M|HG
Symphony of Destruction|Megadeth|1992|M|HG
Holy Wars... The Punishment Due|Megadeth|1990|M|HG
Hangar 18|Megadeth|1990|M|HG
Peace Sells|Megadeth|1986|M|HG
Tornado of Souls|Megadeth|1990|M|HG
A Tout le Monde|Megadeth|1994|M|OD
Sweating Bullets|Megadeth|1992|M|HG
Trust|Megadeth|1997|M|HG
Dystopia|Megadeth|2016|M|HG
Wake Up Dead|Megadeth|1986|M|HG
Raining Blood|Slayer|1986|M|HG
Angel of Death|Slayer|1986|M|HG
South of Heaven|Slayer|1988|M|HG
Seasons in the Abyss|Slayer|1990|M|HG
War Ensemble|Slayer|1990|M|HG
Dead Skin Mask|Slayer|1990|M|HG
Repentless|Slayer|2015|M|HG
Cowboys from Hell|Pantera|1990|M|HG
Walk|Pantera|1992|M|HG
Cemetery Gates|Pantera|1990|M|CL
Domination|Pantera|1990|M|HG
Mouth for War|Pantera|1992|M|HG
This Love|Pantera|1992|M|CL
5 Minutes Alone|Pantera|1994|M|HG
I'm Broken|Pantera|1994|M|HG
Madhouse|Anthrax|1985|M|HG
Caught in a Mosh|Anthrax|1987|M|HG
Indians|Anthrax|1987|M|HG
Antisocial|Anthrax|1988|M|HG
Practice What You Preach|Testament|1989|M|HG
Into the Pit|Testament|1988|M|HG
The New Order|Testament|1988|M|HG
Davidian|Machine Head|1994|M|HG
Halo|Machine Head|2007|M|HG
Imperium|Machine Head|2003|M|HG
Roots Bloody Roots|Sepultura|1996|M|HG
Refuse/Resist|Sepultura|1993|M|HG
Territory|Sepultura|1993|M|HG
Arise|Sepultura|1991|M|HG
Chop Suey!|System of a Down|2001|M|HG
Toxicity|System of a Down|2001|M|HG
B.Y.O.B.|System of a Down|2005|M|HG
Aerials|System of a Down|2001|M|CL
Hypnotize|System of a Down|2005|M|CL
Lonely Day|System of a Down|2005|M|CL
Sugar|System of a Down|1998|M|HG
Spiders|System of a Down|1998|M|CL
Prison Song|System of a Down|2001|M|HG
Radio/Video|System of a Down|2005|M|HG
Freak on a Leash|Korn|1998|M|HG
Blind|Korn|1994|M|HG
Falling Away from Me|Korn|1999|M|HG
Got the Life|Korn|1998|M|HG
Here to Stay|Korn|2002|M|HG
Coming Undone|Korn|2005|M|HG
Duality|Slipknot|2004|M|HG
Before I Forget|Slipknot|2004|M|HG
Psychosocial|Slipknot|2008|M|HG
Wait and Bleed|Slipknot|1999|M|HG
The Devil in I|Slipknot|2014|M|HG
Snuff|Slipknot|2008|M|CL
Left Behind|Slipknot|2001|M|HG
Unsainted|Slipknot|2019|M|HG
In the End|Linkin Park|2000|A|HG
Numb|Linkin Park|2003|A|HG
Crawling|Linkin Park|2000|A|HG
One Step Closer|Linkin Park|2000|A|HG
Faint|Linkin Park|2003|A|HG
Somewhere I Belong|Linkin Park|2003|A|HG
What I've Done|Linkin Park|2007|A|HG
Papercut|Linkin Park|2000|A|HG
Breaking the Habit|Linkin Park|2003|A|CL
Bleed It Out|Linkin Park|2007|A|CR
My Own Summer (Shove It)|Deftones|1997|A|HG
Change (In the House of Flies)|Deftones|2000|A|OD
Be Quiet and Drive|Deftones|1997|A|OD
Diamond Eyes|Deftones|2010|A|HG
Sextape|Deftones|2010|A|CL
Schism|Tool|2001|A|OD
Sober|Tool|1993|A|OD
Forty Six & 2|Tool|1996|A|OD
Vicarious|Tool|2006|A|OD
The Pot|Tool|2006|A|OD
Lateralus|Tool|2001|A|OD
Killing in the Name|Rage Against the Machine|1992|F|HG
Bulls on Parade|Rage Against the Machine|1996|F|HG
Guerrilla Radio|Rage Against the Machine|1999|F|HG
Bombtrack|Rage Against the Machine|1992|F|HG
Know Your Enemy|Rage Against the Machine|1992|F|HG
Sleep Now in the Fire|Rage Against the Machine|1999|F|CR
Testify|Rage Against the Machine|1999|F|HG
Like a Stone|Audioslave|2002|A|CL
Cochise|Audioslave|2002|A|HG
Show Me How to Live|Audioslave|2002|A|CR
Be Yourself|Audioslave|2005|A|CL
I Am the Highway|Audioslave|2002|A|CL
Doesn't Remind Me|Audioslave|2005|A|CL
Under the Bridge|Red Hot Chili Peppers|1991|F|CL
Californication|Red Hot Chili Peppers|1999|F|CL
Scar Tissue|Red Hot Chili Peppers|1999|F|CL
Otherside|Red Hot Chili Peppers|1999|F|CL
Can't Stop|Red Hot Chili Peppers|2002|F|CL
By the Way|Red Hot Chili Peppers|2002|F|CR
Give It Away|Red Hot Chili Peppers|1991|F|CR
Snow (Hey Oh)|Red Hot Chili Peppers|2006|F|CL
Dani California|Red Hot Chili Peppers|2006|F|CR
Suck My Kiss|Red Hot Chili Peppers|1991|F|CR
Around the World|Red Hot Chili Peppers|1999|F|CR
Soul to Squeeze|Red Hot Chili Peppers|1993|F|CL
Dark Necessities|Red Hot Chili Peppers|2016|F|CL
Smells Like Teen Spirit|Nirvana|1991|G|HG
Come as You Are|Nirvana|1991|G|CL
Lithium|Nirvana|1991|G|HG
In Bloom|Nirvana|1991|G|HG
Heart-Shaped Box|Nirvana|1993|G|OD
About a Girl|Nirvana|1989|G|CL
Breed|Nirvana|1991|G|HG
Rape Me|Nirvana|1993|G|OD
Drain You|Nirvana|1991|G|HG
All Apologies|Nirvana|1993|G|CL
Aneurysm|Nirvana|1991|G|HG
You Know You're Right|Nirvana|2002|G|HG
Alive|Pearl Jam|1991|G|OD
Even Flow|Pearl Jam|1991|G|OD
Jeremy|Pearl Jam|1991|G|CL
Black|Pearl Jam|1991|G|CL
Yellow Ledbetter|Pearl Jam|1992|G|CL
Better Man|Pearl Jam|1994|G|CL
Corduroy|Pearl Jam|1994|G|CR
Rearviewmirror|Pearl Jam|1993|G|CR
Once|Pearl Jam|1991|G|OD
Given to Fly|Pearl Jam|1998|G|CL
Black Hole Sun|Soundgarden|1994|G|CL
Spoonman|Soundgarden|1994|G|CR
Outshined|Soundgarden|1991|G|CR
Rusty Cage|Soundgarden|1991|G|CR
Fell on Black Days|Soundgarden|1994|G|CR
The Day I Tried to Live|Soundgarden|1994|G|CR
Burden in My Hand|Soundgarden|1996|G|CL
Jesus Christ Pose|Soundgarden|1991|G|CR
Man in the Box|Alice in Chains|1990|G|OD
Would?|Alice in Chains|1992|G|OD
Rooster|Alice in Chains|1992|G|CL
Them Bones|Alice in Chains|1992|G|HG
Down in a Hole|Alice in Chains|1992|G|CL
No Excuses|Alice in Chains|1994|G|CL
Nutshell|Alice in Chains|1994|G|CL
Check My Brain|Alice in Chains|2009|G|HG
Plush|Stone Temple Pilots|1992|G|OD
Interstate Love Song|Stone Temple Pilots|1994|G|CR
Vasoline|Stone Temple Pilots|1994|G|CR
Creep|Stone Temple Pilots|1992|G|CL
Big Empty|Stone Temple Pilots|1994|G|CL
Trippin' on a Hole in a Paper Heart|Stone Temple Pilots|1996|G|CR
Cherub Rock|The Smashing Pumpkins|1993|A|FZ
Today|The Smashing Pumpkins|1993|A|FZ
Bullet with Butterfly Wings|The Smashing Pumpkins|1995|A|FZ
1979|The Smashing Pumpkins|1995|A|CL
Zero|The Smashing Pumpkins|1995|A|FZ
Tonight, Tonight|The Smashing Pumpkins|1995|A|CL
Disarm|The Smashing Pumpkins|1993|A|CL
Ava Adore|The Smashing Pumpkins|1998|A|FZ
Everlong|Foo Fighters|1997|A|HG
The Pretender|Foo Fighters|2007|A|HG
Learn to Fly|Foo Fighters|1999|A|CR
My Hero|Foo Fighters|1997|A|CR
Best of You|Foo Fighters|2005|A|HG
Times Like These|Foo Fighters|2002|A|CR
All My Life|Foo Fighters|2002|A|HG
Monkey Wrench|Foo Fighters|1997|A|HG
Walk|Foo Fighters|2011|A|CR
Rope|Foo Fighters|2011|A|CR
Run|Foo Fighters|2017|A|HG
This Is a Call|Foo Fighters|1995|A|CR
Basket Case|Green Day|1994|A|HG
American Idiot|Green Day|2004|A|HG
Boulevard of Broken Dreams|Green Day|2004|A|CL
When I Come Around|Green Day|1994|A|CR
Welcome to Paradise|Green Day|1994|A|HG
Holiday|Green Day|2004|A|HG
Longview|Green Day|1994|A|CL
Brain Stew|Green Day|1995|A|CR
Hitchin' a Ride|Green Day|1997|A|CR
Minority|Green Day|2000|A|CR
21 Guns|Green Day|2009|A|CL
Know Your Enemy|Green Day|2009|A|CR
Jesus of Suburbia|Green Day|2004|A|HG
Wake Me Up When September Ends|Green Day|2004|A|CL
Self Esteem|The Offspring|1994|A|HG
The Kids Aren't Alright|The Offspring|1998|A|HG
Come Out and Play|The Offspring|1994|A|CR
Pretty Fly (For a White Guy)|The Offspring|1998|A|CR
Gone Away|The Offspring|1997|A|HG
You're Gonna Go Far, Kid|The Offspring|2008|A|CR
All the Small Things|blink-182|1999|A|HG
What's My Age Again?|blink-182|1999|A|CR
Adam's Song|blink-182|1999|A|CL
Dammit|blink-182|1997|A|CR
I Miss You|blink-182|2003|A|CL
Feeling This|blink-182|2003|A|CR
First Date|blink-182|2001|A|CR
The Rock Show|blink-182|2001|A|CR
Fat Lip|Sum 41|2001|A|HG
In Too Deep|Sum 41|2001|A|CR
Still Waiting|Sum 41|2002|A|HG
The Hell Song|Sum 41|2002|A|CR
Buddy Holly|Weezer|1994|A|CR
Say It Ain't So|Weezer|1994|A|CL
Island in the Sun|Weezer|2001|A|CL
Undone - The Sweater Song|Weezer|1994|A|CL
Hash Pipe|Weezer|2001|A|CR
Beverly Hills|Weezer|2005|A|CR
Losing My Religion|R.E.M.|1991|A|CL
The One I Love|R.E.M.|1987|A|CL
It's the End of the World as We Know It|R.E.M.|1987|A|CL
Man on the Moon|R.E.M.|1992|A|CL
What's the Frequency, Kenneth?|R.E.M.|1994|A|FZ
Orange Crush|R.E.M.|1988|A|CR
Creep|Radiohead|1992|A|CL
Paranoid Android|Radiohead|1997|A|OD
Karma Police|Radiohead|1997|A|CL
No Surprises|Radiohead|1997|A|CL
Just|Radiohead|1995|A|OD
High and Dry|Radiohead|1995|A|CL
Street Spirit (Fade Out)|Radiohead|1995|A|CL
My Iron Lung|Radiohead|1994|A|OD
Airbag|Radiohead|1997|A|CR
There There|Radiohead|2003|A|CR
Bodysnatchers|Radiohead|2007|A|FZ
Weird Fishes/Arpeggi|Radiohead|2007|A|CL
Plug In Baby|Muse|2001|A|FZ
Knights of Cydonia|Muse|2006|A|FZ
Hysteria|Muse|2003|A|FZ
Supermassive Black Hole|Muse|2006|A|FZ
Time Is Running Out|Muse|2003|A|CL
Stockholm Syndrome|Muse|2003|A|HG
New Born|Muse|2001|A|HG
Uprising|Muse|2009|A|FZ
Starlight|Muse|2006|A|CL
Reapers|Muse|2015|A|HG
Psycho|Muse|2015|A|HG
Muscle Museum|Muse|1999|A|OD
Yellow|Coldplay|2000|A|CL
Shiver|Coldplay|2000|A|CL
In My Place|Coldplay|2002|A|CL
God Put a Smile upon Your Face|Coldplay|2002|A|CR
Fix You|Coldplay|2005|A|CL
Viva la Vida|Coldplay|2008|A|CL
Wonderwall|Oasis|1995|A|CL
Don't Look Back in Anger|Oasis|1995|A|CL
Live Forever|Oasis|1994|A|CR
Champagne Supernova|Oasis|1995|A|CL
Supersonic|Oasis|1994|A|CR
Cigarettes & Alcohol|Oasis|1994|A|CR
Morning Glory|Oasis|1995|A|CR
Rock 'n' Roll Star|Oasis|1994|A|CR
Slide Away|Oasis|1994|A|CR
Stop Crying Your Heart Out|Oasis|2002|A|CL
Song 2|Blur|1997|A|FZ
Beetlebum|Blur|1997|A|CL
Coffee & TV|Blur|1999|A|CL
Parklife|Blur|1994|A|CR
Girls & Boys|Blur|1994|A|CL
Do I Wanna Know?|Arctic Monkeys|2013|A|FZ
R U Mine?|Arctic Monkeys|2013|A|FZ
I Bet You Look Good on the Dancefloor|Arctic Monkeys|2005|A|CR
Fluorescent Adolescent|Arctic Monkeys|2007|A|CL
505|Arctic Monkeys|2007|A|CL
Arabella|Arctic Monkeys|2013|A|FZ
Brianstorm|Arctic Monkeys|2007|A|CR
When the Sun Goes Down|Arctic Monkeys|2006|A|CR
Snap Out of It|Arctic Monkeys|2013|A|CR
Crying Lightning|Arctic Monkeys|2009|A|CR
Teddy Picker|Arctic Monkeys|2007|A|CR
Why'd You Only Call Me When You're High?|Arctic Monkeys|2013|A|CL
Last Nite|The Strokes|2001|A|CR
Reptilia|The Strokes|2003|A|CR
Someday|The Strokes|2001|A|CL
Hard to Explain|The Strokes|2001|A|CR
The Modern Age|The Strokes|2001|A|CR
Under Cover of Darkness|The Strokes|2011|A|CR
You Only Live Once|The Strokes|2006|A|CR
Juicebox|The Strokes|2005|A|FZ
Seven Nation Army|The White Stripes|2003|A|FZ
Fell in Love with a Girl|The White Stripes|2001|A|FZ
The Hardest Button to Button|The White Stripes|2003|A|FZ
Blue Orchid|The White Stripes|2005|A|FZ
Icky Thump|The White Stripes|2007|A|FZ
Dead Leaves and the Dirty Ground|The White Stripes|2001|A|FZ
Lonely Boy|The Black Keys|2011|B|FZ
Tighten Up|The Black Keys|2010|B|FZ
Gold on the Ceiling|The Black Keys|2011|B|FZ
Howlin' for You|The Black Keys|2010|B|FZ
Fever|The Black Keys|2014|B|FZ
Little Black Submarines|The Black Keys|2011|B|OD
I Got Mine|The Black Keys|2008|B|FZ
Your Touch|The Black Keys|2006|B|FZ
No One Knows|Queens of the Stone Age|2002|A|FZ
Go with the Flow|Queens of the Stone Age|2002|A|FZ
Little Sister|Queens of the Stone Age|2005|A|CR
Make It wit Chu|Queens of the Stone Age|2007|A|CL
The Way You Used to Do|Queens of the Stone Age|2017|A|CR
My God Is the Sun|Queens of the Stone Age|2013|A|FZ
Sick, Sick, Sick|Queens of the Stone Age|2007|A|HG
Sex on Fire|Kings of Leon|2008|A|CR
Use Somebody|Kings of Leon|2008|A|CL
The Bucket|Kings of Leon|2004|A|CR
Molly's Chambers|Kings of Leon|2003|A|CR
Waste a Moment|Kings of Leon|2016|A|CR
Closer|Kings of Leon|2008|A|CL
Mr. Brightside|The Killers|2004|A|CR
When You Were Young|The Killers|2006|A|CR
Somebody Told Me|The Killers|2004|A|CR
Human|The Killers|2008|A|CL
All These Things That I've Done|The Killers|2004|A|CL
The Man|The Killers|2017|A|CL
Evil|Interpol|2004|A|CL
Slow Hands|Interpol|2004|A|CR
Obstacle 1|Interpol|2002|A|CR
PDA|Interpol|2002|A|CR
Take Me Out|Franz Ferdinand|2004|A|CR
Do You Want To|Franz Ferdinand|2005|A|CR
No You Girls|Franz Ferdinand|2009|A|CR
Fire|Kasabian|2009|A|CR
Club Foot|Kasabian|2004|A|FZ
Underdog|Kasabian|2009|A|CR
Figure It Out|Royal Blood|2014|A|FZ
Out of the Black|Royal Blood|2014|A|FZ
Little Monster|Royal Blood|2014|A|FZ
Lights Out|Royal Blood|2017|A|FZ
Trouble's Coming|Royal Blood|2020|A|FZ
With or Without You|U2|1987|R|CL
Where the Streets Have No Name|U2|1987|R|CL
Sunday Bloody Sunday|U2|1983|R|CL
Pride (In the Name of Love)|U2|1984|R|CL
I Still Haven't Found What I'm Looking For|U2|1987|R|CL
One|U2|1991|R|CL
Beautiful Day|U2|2000|R|CL
Vertigo|U2|2004|R|CR
Mysterious Ways|U2|1991|R|CR
Bullet the Blue Sky|U2|1987|R|OD
New Year's Day|U2|1983|R|CL
Elevation|U2|2000|R|FZ
Every Breath You Take|The Police|1983|R|CL
Message in a Bottle|The Police|1979|R|CL
Roxanne|The Police|1978|R|CL
Walking on the Moon|The Police|1979|R|CL
So Lonely|The Police|1978|R|CL
Don't Stand So Close to Me|The Police|1980|R|CL
Synchronicity II|The Police|1983|R|CR
Can't Stand Losing You|The Police|1978|R|CL
Sultans of Swing|Dire Straits|1978|R|CL
Money for Nothing|Dire Straits|1985|R|CR
Brothers in Arms|Dire Straits|1985|R|CL
Romeo and Juliet|Dire Straits|1980|R|CL
Telegraph Road|Dire Straits|1982|R|CL
Walk of Life|Dire Straits|1985|R|CL
Tunnel of Love|Dire Straits|1980|R|CL
Ziggy Stardust|David Bowie|1972|R|CR
Rebel Rebel|David Bowie|1974|R|CR
Suffragette City|David Bowie|1972|R|CR
Heroes|David Bowie|1977|R|CL
The Man Who Sold the World|David Bowie|1970|R|CL
Moonage Daydream|David Bowie|1972|R|CR
Get It On|T. Rex|1971|R|CR
20th Century Boy|T. Rex|1973|R|CR
Children of the Revolution|T. Rex|1972|R|CR
Eruption|Van Halen|1978|HR|LD
Runnin' with the Devil|Van Halen|1978|HR|CR
Panama|Van Halen|1984|HR|CR
Jump|Van Halen|1984|HR|CR
Hot for Teacher|Van Halen|1984|HR|LD
Ain't Talkin' 'bout Love|Van Halen|1978|HR|CR
Unchained|Van Halen|1981|HR|CR
Dance the Night Away|Van Halen|1979|HR|CR
Why Can't This Be Love|Van Halen|1986|HR|CR
Right Now|Van Halen|1991|HR|CR
Sweet Child O' Mine|Guns N' Roses|1987|HR|LD
Welcome to the Jungle|Guns N' Roses|1987|HR|CR
Paradise City|Guns N' Roses|1987|HR|CR
November Rain|Guns N' Roses|1991|HR|LD
Don't Cry|Guns N' Roses|1991|HR|CL
Patience|Guns N' Roses|1988|HR|CL
Civil War|Guns N' Roses|1991|HR|CL
Estranged|Guns N' Roses|1991|HR|LD
Mr. Brownstone|Guns N' Roses|1987|HR|CR
Nightrain|Guns N' Roses|1987|HR|CR
Livin' on a Prayer|Bon Jovi|1986|HR|CR
You Give Love a Bad Name|Bon Jovi|1986|HR|CR
Wanted Dead or Alive|Bon Jovi|1986|HR|CL
It's My Life|Bon Jovi|2000|HR|CR
Bad Medicine|Bon Jovi|1988|HR|CR
Runaway|Bon Jovi|1984|HR|CR
Blaze of Glory|Bon Jovi|1990|HR|CL
Keep the Faith|Bon Jovi|1992|HR|CR
Pour Some Sugar on Me|Def Leppard|1987|HR|CR
Photograph|Def Leppard|1983|HR|CR
Animal|Def Leppard|1987|HR|CR
Hysteria|Def Leppard|1987|HR|CL
Love Bites|Def Leppard|1987|HR|CL
Rock of Ages|Def Leppard|1983|HR|CR
Rock You Like a Hurricane|Scorpions|1984|HR|CR
Wind of Change|Scorpions|1990|HR|CL
Still Loving You|Scorpions|1984|HR|LD
Big City Nights|Scorpions|1984|HR|CR
No One Like You|Scorpions|1982|HR|CR
Send Me an Angel|Scorpions|1990|HR|CL
Blackout|Scorpions|1982|HR|CR
Holiday|Scorpions|1979|HR|CL
Here I Go Again|Whitesnake|1987|HR|CR
Still of the Night|Whitesnake|1987|HR|CR
Is This Love|Whitesnake|1987|HR|CL
The Final Countdown|Europe|1986|HR|LD
Carrie|Europe|1986|HR|CL
Rock the Night|Europe|1986|HR|CR
Since You Been Gone|Rainbow|1979|HR|CR
Man on the Silver Mountain|Rainbow|1975|HR|CR
Stargazer|Rainbow|1976|HR|CR
Long Live Rock 'n' Roll|Rainbow|1978|HR|CR
Catch the Rainbow|Rainbow|1975|HR|CL
Holy Diver|Dio|1983|M|CR
Rainbow in the Dark|Dio|1983|M|CR
The Last in Line|Dio|1984|M|CR
We Rock|Dio|1984|M|HG
Crazy Train|Ozzy Osbourne|1980|M|CR
Mr. Crowley|Ozzy Osbourne|1980|M|CR
Bark at the Moon|Ozzy Osbourne|1983|M|HG
No More Tears|Ozzy Osbourne|1991|M|CR
Mama, I'm Coming Home|Ozzy Osbourne|1991|M|CL
I Don't Know|Ozzy Osbourne|1980|M|CR
Flying High Again|Ozzy Osbourne|1981|M|CR
School's Out|Alice Cooper|1972|HR|CR
Poison|Alice Cooper|1989|HR|CR
No More Mr. Nice Guy|Alice Cooper|1973|HR|CR
I'm Eighteen|Alice Cooper|1971|HR|CR
Rock and Roll All Nite|KISS|1975|HR|CR
Detroit Rock City|KISS|1976|HR|CR
I Was Made for Lovin' You|KISS|1979|HR|CR
Shout It Out Loud|KISS|1976|HR|CR
Love Gun|KISS|1977|HR|CR
Deuce|KISS|1974|HR|CR
The Boys Are Back in Town|Thin Lizzy|1976|HR|CR
Jailbreak|Thin Lizzy|1976|HR|CR
Whiskey in the Jar|Thin Lizzy|1972|R|CL
Emerald|Thin Lizzy|1976|HR|CR
Cowboy Song|Thin Lizzy|1976|HR|CR
Free Bird|Lynyrd Skynyrd|1973|R|LD
Sweet Home Alabama|Lynyrd Skynyrd|1974|R|CL
Simple Man|Lynyrd Skynyrd|1973|R|CL
Gimme Three Steps|Lynyrd Skynyrd|1973|R|CR
That Smell|Lynyrd Skynyrd|1977|R|CR
Tuesday's Gone|Lynyrd Skynyrd|1973|R|CL
La Grange|ZZ Top|1973|B|CR
Sharp Dressed Man|ZZ Top|1983|B|CR
Gimme All Your Lovin'|ZZ Top|1983|B|CR
Tush|ZZ Top|1975|B|CR
Legs|ZZ Top|1983|B|CR
Cheap Sunglasses|ZZ Top|1979|B|CR
Just Got Paid|ZZ Top|1972|B|CR
Pride and Joy|Stevie Ray Vaughan|1983|B|OD
Texas Flood|Stevie Ray Vaughan|1983|B|OD
Cold Shot|Stevie Ray Vaughan|1984|B|CL
Couldn't Stand the Weather|Stevie Ray Vaughan|1984|B|OD
Scuttle Buttin'|Stevie Ray Vaughan|1984|B|OD
Love Struck Baby|Stevie Ray Vaughan|1983|B|CR
Crossfire|Stevie Ray Vaughan|1989|B|OD
Little Wing|Stevie Ray Vaughan|1991|B|CL
Still Got the Blues|Gary Moore|1990|B|LD
Parisienne Walkways|Gary Moore|1978|B|LD
Walking by Myself|Gary Moore|1990|B|OD
Oh Pretty Woman|Gary Moore|1990|B|OD
The Loner|Gary Moore|1987|B|LD
The Thrill Is Gone|B.B. King|1969|B|CL
Every Day I Have the Blues|B.B. King|1955|B|CL
Sweet Little Angel|B.B. King|1956|B|CL
Rock Me Baby|B.B. King|1964|B|CL
Layla|Eric Clapton|1970|B|OD
Cocaine|Eric Clapton|1977|B|CR
Wonderful Tonight|Eric Clapton|1977|B|CL
Tears in Heaven|Eric Clapton|1992|B|CL
Bell Bottom Blues|Eric Clapton|1970|B|CL
I Shot the Sheriff|Eric Clapton|1974|B|CL
Before You Accuse Me|Eric Clapton|1989|B|OD
Forever Man|Eric Clapton|1985|B|CR
Gravity|John Mayer|2006|B|CL
Slow Dancing in a Burning Room|John Mayer|2006|B|CL
Neon|John Mayer|2001|B|CL
Belief|John Mayer|2006|B|CL
Who Did You Think I Was|John Mayer|2005|B|CR
Vultures|John Mayer|2006|B|CL
Black Magic Woman|Santana|1970|B|OD
Oye Como Va|Santana|1970|B|OD
Smooth|Santana|1999|B|OD
Europa|Santana|1976|B|LD
Samba Pa Ti|Santana|1970|B|LD
Soul Sacrifice|Santana|1969|P|OD
The Chain|Fleetwood Mac|1977|R|CL
Go Your Own Way|Fleetwood Mac|1977|R|CL
Dreams|Fleetwood Mac|1977|R|CL
Rhiannon|Fleetwood Mac|1975|R|CL
Landslide|Fleetwood Mac|1975|R|CL
Albatross|Fleetwood Mac|1968|B|CL
More Than a Feeling|Boston|1976|R|CR
Peace of Mind|Boston|1976|R|CR
Foreplay/Long Time|Boston|1976|R|CR
Don't Stop Believin'|Journey|1981|R|CL
Any Way You Want It|Journey|1980|R|CR
Separate Ways|Journey|1983|R|CR
Wheel in the Sky|Journey|1978|R|CL
Juke Box Hero|Foreigner|1981|R|CR
Cold as Ice|Foreigner|1977|R|CL
Hot Blooded|Foreigner|1978|R|CR
Urgent|Foreigner|1981|R|CR
Hold the Line|Toto|1978|R|CR
Rosanna|Toto|1982|R|CL
Africa|Toto|1982|R|CL
Carry On Wayward Son|Kansas|1976|R|CR
Dust in the Wind|Kansas|1977|R|CL
Tom Sawyer|Rush|1981|R|CR
The Spirit of Radio|Rush|1980|R|CR
Limelight|Rush|1981|R|CR
YYZ|Rush|1981|R|CR
Closer to the Heart|Rush|1977|R|CL
Working Man|Rush|1974|HR|CR
Fly by Night|Rush|1975|R|CR
Subdivisions|Rush|1982|R|CL
Freewill|Rush|1980|R|CR
2112 Overture|Rush|1976|HR|CR
Roundabout|Yes|1971|R|CL
Owner of a Lonely Heart|Yes|1983|R|CR
I've Seen All Good People|Yes|1971|R|CL
Pull Me Under|Dream Theater|1992|M|HG
Metropolis Pt. 1|Dream Theater|1992|M|HG
The Spirit Carries On|Dream Theater|1999|M|LD
On the Backs of Angels|Dream Theater|2011|M|HG
Panic Attack|Dream Theater|2005|M|HG
As I Am|Dream Theater|2003|M|HG
Blackwater Park|Opeth|2001|M|HG
Ghost of Perdition|Opeth|2005|M|HG
The Drapery Falls|Opeth|2001|M|OD
Deliverance|Opeth|2002|M|HG
Trains|Porcupine Tree|2002|A|CL
Blackest Eyes|Porcupine Tree|2002|A|HG
Lazarus|Porcupine Tree|2005|A|CL
Shallow|Porcupine Tree|2005|A|HG
Blood and Thunder|Mastodon|2004|M|HG
Oblivion|Mastodon|2009|M|HG
The Motherload|Mastodon|2014|M|HG
Colony of Birchmen|Mastodon|2006|M|HG
Flying Whales|Gojira|2005|M|HG
Stranded|Gojira|2016|M|HG
Silvera|Gojira|2016|M|HG
The Art of Dying|Gojira|2008|M|HG
Square Hammer|Ghost|2016|M|CR
Cirice|Ghost|2015|M|CR
Dance Macabre|Ghost|2018|M|CR
Rats|Ghost|2018|M|CR
Bat Country|Avenged Sevenfold|2005|M|HG
Nightmare|Avenged Sevenfold|2010|M|HG
Hail to the King|Avenged Sevenfold|2013|M|HG
Afterlife|Avenged Sevenfold|2007|M|HG
Unholy Confessions|Avenged Sevenfold|2003|M|HG
So Far Away|Avenged Sevenfold|2010|M|CL
Tears Don't Fall|Bullet for My Valentine|2005|M|HG
All These Things I Hate|Bullet for My Valentine|2005|M|CL
Your Betrayal|Bullet for My Valentine|2010|M|HG
Scream Aim Fire|Bullet for My Valentine|2008|M|HG
In Waves|Trivium|2011|M|HG
Pull Harder on the Strings of Your Martyr|Trivium|2005|M|HG
Strife|Trivium|2013|M|HG
The Heart from Your Hate|Trivium|2017|M|HG
My Curse|Killswitch Engage|2006|M|HG
The End of Heartache|Killswitch Engage|2004|M|HG
Rose of Sharyn|Killswitch Engage|2004|M|HG
In Due Time|Killswitch Engage|2013|M|HG
Can You Feel My Heart|Bring Me the Horizon|2013|M|HG
Throne|Bring Me the Horizon|2015|M|HG
Shadow Moses|Bring Me the Horizon|2013|M|HG
Drown|Bring Me the Horizon|2014|M|CR
Misery Business|Paramore|2007|A|HG
That's What You Get|Paramore|2007|A|CR
Ignorance|Paramore|2009|A|HG
Still Into You|Paramore|2013|A|CR
Decode|Paramore|2008|A|OD
Bring Me to Life|Evanescence|2003|A|HG
Going Under|Evanescence|2003|A|HG
Call Me When You're Sober|Evanescence|2006|A|HG
Join Me in Death|HIM|1999|A|OD
Wings of a Butterfly|HIM|2005|A|CR
The Funeral of Hearts|HIM|2003|A|OD
Right Here in My Arms|HIM|1999|A|CR
Du Hast|Rammstein|1997|M|HG
Sonne|Rammstein|2001|M|HG
Ich Will|Rammstein|2001|M|HG
Mein Herz Brennt|Rammstein|2001|M|HG
Deutschland|Rammstein|2019|M|HG
Nemo|Nightwish|2004|M|HG
Wish I Had an Angel|Nightwish|2004|M|HG
Amaranth|Nightwish|2007|M|HG
Zombie|The Cranberries|1994|A|FZ
Linger|The Cranberries|1993|A|CL
Dreams|The Cranberries|1992|A|CL
Salvation|The Cranberries|1996|A|CR
Only Happy When It Rains|Garbage|1995|A|FZ
Stupid Girl|Garbage|1995|A|CL
I Think I'm Paranoid|Garbage|1998|A|FZ
Celebrity Skin|Hole|1998|A|CR
Violet|Hole|1994|A|HG
Malibu|Hole|1998|A|CL
Every You Every Me|Placebo|1998|A|CR
Pure Morning|Placebo|1998|A|FZ
The Bitter End|Placebo|2003|A|CR
Special K|Placebo|2000|A|CR
Machinehead|Bush|1994|A|HG
Glycerine|Bush|1994|A|CL
Comedown|Bush|1994|A|OD
Swallowed|Bush|1996|A|OD
Tomorrow|Silverchair|1994|G|OD
Freak|Silverchair|1997|G|HG
Straight Lines|Silverchair|2007|A|CR
Drive|Incubus|1999|A|CL
Wish You Were Here|Incubus|2001|A|CL
Pardon Me|Incubus|1999|A|HG
Megalomaniac|Incubus|2004|A|HG
Anna Molly|Incubus|2006|A|CR
Are You Gonna Be My Girl|Jet|2003|A|CR
Cold Hard Bitch|Jet|2003|A|CR
Rollover DJ|Jet|2003|A|CR
Woman|Wolfmother|2005|HR|FZ
Joker and the Thief|Wolfmother|2005|HR|FZ
White Unicorn|Wolfmother|2005|HR|FZ
Highway Tune|Greta Van Fleet|2017|HR|CR
Safari Song|Greta Van Fleet|2017|HR|CR
When the Curtain Falls|Greta Van Fleet|2018|HR|CR
Heat Above|Greta Van Fleet|2021|HR|CL
Keep on Swinging|Rival Sons|2012|HR|CR
Pressure and Time|Rival Sons|2011|HR|CR
Do Your Worst|Rival Sons|2019|HR|FZ
I Believe in a Thing Called Love|The Darkness|2003|HR|CR
Growing on Me|The Darkness|2003|HR|CR
Runnin' Wild|Airbourne|2007|HR|CR
Too Much, Too Young, Too Fast|Airbourne|2007|HR|CR
Crazy Bitch|Buckcherry|2006|HR|CR
Lit Up|Buckcherry|1999|HR|CR
Slither|Velvet Revolver|2004|HR|CR
Fall to Pieces|Velvet Revolver|2004|HR|LD
Hate to Say I Told You So|The Hives|2000|A|CR
Main Offender|The Hives|2000|A|CR
Get Free|The Vines|2002|A|HG
Chelsea Dagger|The Fratellis|2006|A|CR
I Predict a Riot|Kaiser Chiefs|2004|A|CR
Ruby|Kaiser Chiefs|2007|A|CR
Munich|Editors|2005|A|CL
Chasing Cars|Snow Patrol|2006|A|CL
Run|Snow Patrol|2003|A|CL
Buck Rogers|Feeder|2001|A|CR
Dakota|Stereophonics|2005|A|CR
The Bartender and the Thief|Stereophonics|1998|A|CR
Maybe Tomorrow|Stereophonics|2003|A|CL
A Design for Life|Manic Street Preachers|1996|A|CL
Motorcycle Emptiness|Manic Street Preachers|1992|A|CL
If You Tolerate This Your Children Will Be Next|Manic Street Preachers|1998|A|CL
Why Does It Always Rain on Me?|Travis|1999|A|CL
Bitter Sweet Symphony|The Verve|1997|A|CL
The Drugs Don't Work|The Verve|1997|A|CL
Lucky Man|The Verve|1997|A|CL
Beautiful Ones|Suede|1996|A|CR
Animal Nitrate|Suede|1993|A|CR
Trash|Suede|1996|A|CR
Common People|Pulp|1995|A|CR
Disco 2000|Pulp|1995|A|CR
Alright|Supergrass|1995|A|CL
Moving|Supergrass|1999|A|CL
This Charming Man|The Smiths|1983|A|CL
How Soon Is Now?|The Smiths|1985|A|CL
There Is a Light That Never Goes Out|The Smiths|1986|A|CL
Bigmouth Strikes Again|The Smiths|1986|A|CL
What Difference Does It Make?|The Smiths|1984|A|CL
Love Will Tear Us Apart|Joy Division|1980|A|CL
Disorder|Joy Division|1979|A|CR
Transmission|Joy Division|1979|A|CR
Just Like Heaven|The Cure|1987|A|CL
Boys Don't Cry|The Cure|1979|A|CL
Friday I'm in Love|The Cure|1992|A|CL
In Between Days|The Cure|1985|A|CL
A Forest|The Cure|1980|A|CL
Lovesong|The Cure|1989|A|CL
Where Is My Mind?|Pixies|1988|A|CL
Here Comes Your Man|Pixies|1989|A|CL
Debaser|Pixies|1989|A|CR
Monkey Gone to Heaven|Pixies|1989|A|CL
Wave of Mutilation|Pixies|1989|A|CR
Teen Age Riot|Sonic Youth|1988|A|FZ
Kool Thing|Sonic Youth|1990|A|FZ
100%|Sonic Youth|1992|A|FZ
Feel the Pain|Dinosaur Jr.|1994|A|FZ
Freak Scene|Dinosaur Jr.|1988|A|FZ
Start Choppin|Dinosaur Jr.|1993|A|FZ
Only Shallow|My Bloody Valentine|1991|A|FZ
When You Sleep|My Bloody Valentine|1991|A|FZ
Jane Says|Jane's Addiction|1988|A|CL
Been Caught Stealing|Jane's Addiction|1990|A|CR
Mountain Song|Jane's Addiction|1988|A|CR
Epic|Faith No More|1989|A|HG
Midlife Crisis|Faith No More|1992|A|CR
Falling to Pieces|Faith No More|1989|A|CR
Easy|Faith No More|1992|A|CL
Jerry Was a Race Car Driver|Primus|1991|F|FZ
My Name Is Mud|Primus|1993|F|FZ
Electric Worry|Clutch|2007|HR|CR
X-Ray Visions|Clutch|2015|HR|CR
A Shogun Named Marcus|Clutch|1993|HR|HG
Space Lord|Monster Magnet|1998|HR|FZ
Negasonic Teenage Warhead|Monster Magnet|1995|HR|FZ
Green Machine|Kyuss|1992|HR|FZ
Demon Cleaner|Kyuss|1994|HR|FZ
One Inch Man|Kyuss|1995|HR|FZ
Evil Eye|Fu Manchu|1997|HR|FZ
Dragonaut|Sleep|1992|M|FZ
Stinkfist|Tool|1996|A|OD
Suicide Messiah|Black Label Society|2005|M|HG
Stillborn|Black Label Society|2003|M|HG
In This River|Black Label Society|2005|M|CL
Isolation|Alter Bridge|2010|M|HG
Blackbird|Alter Bridge|2007|M|LD
Metalingus|Alter Bridge|2004|M|HG
Open Your Eyes|Alter Bridge|2004|M|HG
Higher|Creed|1999|A|CR
My Sacrifice|Creed|2001|A|CR
One Last Breath|Creed|2002|A|CL
With Arms Wide Open|Creed|2000|A|CL
How You Remind Me|Nickelback|2001|A|CR
Photograph|Nickelback|2005|A|CL
Burn It to the Ground|Nickelback|2008|A|HG
Someday|Nickelback|2003|A|CR
Kryptonite|3 Doors Down|2000|A|CR
Loser|3 Doors Down|2000|A|CR
When I'm Gone|3 Doors Down|2002|A|CR
Fake It|Seether|2007|A|HG
Remedy|Seether|2005|A|HG
Broken|Seether|2004|A|CL
The Diary of Jane|Breaking Benjamin|2006|A|HG
Breath|Breaking Benjamin|2006|A|HG
So Cold|Breaking Benjamin|2004|A|HG
Second Chance|Shinedown|2008|A|CL
Sound of Madness|Shinedown|2008|A|HG
45|Shinedown|2003|A|CL
Enemies|Shinedown|2012|A|HG
I Stand Alone|Godsmack|2002|M|HG
Awake|Godsmack|2000|M|HG
Voodoo|Godsmack|1998|M|CL
Down with the Sickness|Disturbed|2000|M|HG
Stricken|Disturbed|2005|M|HG
Indestructible|Disturbed|2008|M|HG
The Sound of Silence|Disturbed|2015|M|CL
Ten Thousand Fists|Disturbed|2005|M|HG
The Bleeding|Five Finger Death Punch|2007|M|HG
Wrong Side of Heaven|Five Finger Death Punch|2013|M|CL
Bad Company|Five Finger Death Punch|2009|M|HG
Still Counting|Volbeat|2008|M|HG
The Devil's Bleeding Crown|Volbeat|2016|M|HG
Lola Montez|Volbeat|2013|M|CR
Sad Man's Tongue|Volbeat|2007|M|CR
Take This Life|In Flames|2006|M|HG
The Quiet Place|In Flames|2004|M|HG
Cloud Connected|In Flames|2002|M|HG
Only for the Weak|In Flames|2000|M|HG
Are You Dead Yet?|Children of Bodom|2005|M|HG
Downfall|Children of Bodom|1999|M|HG
Needled 24/7|Children of Bodom|2003|M|HG
Nemesis|Arch Enemy|2005|M|HG
War Eternal|Arch Enemy|2014|M|HG
Twilight of the Thunder God|Amon Amarth|2008|M|HG
Guardians of Asgaard|Amon Amarth|2008|M|HG
Raven's Flight|Amon Amarth|2019|M|HG
Laid to Rest|Lamb of God|2004|M|HG
Redneck|Lamb of God|2006|M|HG
Walk with Me in Hell|Lamb of God|2006|M|HG
512|Lamb of God|2015|M|HG
Bleed|Meshuggah|2008|M|HG
Rational Gaze|Meshuggah|2002|M|HG
Scarlet|Periphery|2012|M|HG
Alpha|Periphery|2015|M|HG
CAFO|Animals as Leaders|2009|M|HG
Physical Education|Animals as Leaders|2014|M|HG
G.O.A.T.|Polyphia|2018|A|CL
Playing God|Polyphia|2022|A|CL
Electric Sunrise|Plini|2016|A|CL
The Shape of Colour|Intervals|2015|A|CL
Surfing with the Alien|Joe Satriani|1987|R|LD
Always with Me, Always with You|Joe Satriani|1987|R|LD
Satch Boogie|Joe Satriani|1987|R|LD
Summer Song|Joe Satriani|1992|R|LD
Flying in a Blue Dream|Joe Satriani|1989|R|LD
For the Love of God|Steve Vai|1990|R|LD
Tender Surrender|Steve Vai|1995|R|LD
The Attitude Song|Steve Vai|1984|R|LD
Bad Horsie|Steve Vai|1995|R|FZ
Far Beyond the Sun|Yngwie Malmsteen|1984|M|LD
Black Star|Yngwie Malmsteen|1984|M|LD
Rising Force|Yngwie Malmsteen|1988|M|LD
Technical Difficulties|Paul Gilbert|1991|R|LD
Scarified|Paul Gilbert|1989|R|LD
To Be with You|Mr. Big|1991|R|CL
Daddy, Brother, Lover, Little Boy|Mr. Big|1991|HR|CR
Green-Tinted Sixties Mind|Mr. Big|1991|HR|CL
More Than Words|Extreme|1990|R|CL
Get the Funk Out|Extreme|1990|F|CR
Hole Hearted|Extreme|1990|R|CL
Cult of Personality|Living Colour|1988|HR|HG
Glamour Boys|Living Colour|1988|F|CL
Are You Gonna Go My Way|Lenny Kravitz|1993|R|CR
Fly Away|Lenny Kravitz|1998|R|CR
American Woman|Lenny Kravitz|1999|R|FZ
It Ain't Over 'til It's Over|Lenny Kravitz|1991|R|CL
Purple Rain|Prince|1984|R|CL
When Doves Cry|Prince|1984|R|CL
Kiss|Prince|1986|F|CL
Johnny B. Goode|Chuck Berry|1958|R|CR
Roll Over Beethoven|Chuck Berry|1956|R|CR
Maybellene|Chuck Berry|1955|R|CL
Sweet Little Sixteen|Chuck Berry|1958|R|CL
Jailhouse Rock|Elvis Presley|1957|R|CL
Hound Dog|Elvis Presley|1956|R|CL
That's All Right|Elvis Presley|1954|R|CL
Peggy Sue|Buddy Holly|1957|R|CL
That'll Be the Day|Buddy Holly|1957|R|CL
Oh, Pretty Woman|Roy Orbison|1964|R|CL
Good Vibrations|The Beach Boys|1966|R|CL
Wouldn't It Be Nice|The Beach Boys|1966|R|CL
Surfin' U.S.A.|The Beach Boys|1963|R|CL
Mr. Tambourine Man|The Byrds|1965|R|CL
Turn! Turn! Turn!|The Byrds|1965|R|CL
Eight Miles High|The Byrds|1966|P|CL
Rockin' in the Free World|Neil Young|1989|R|FZ
Hey Hey, My My|Neil Young|1979|R|FZ
Cinnamon Girl|Neil Young|1969|R|FZ
Heart of Gold|Neil Young|1972|R|CL
Cortez the Killer|Neil Young|1975|R|OD
Like a Hurricane|Neil Young|1977|R|FZ
Ohio|Crosby, Stills, Nash & Young|1970|R|CR
Woodstock|Crosby, Stills, Nash & Young|1970|R|CR
Like a Rolling Stone|Bob Dylan|1965|R|CL
Knockin' on Heaven's Door|Bob Dylan|1973|R|CL
Subterranean Homesick Blues|Bob Dylan|1965|R|CL
Hurricane|Bob Dylan|1976|R|CL
American Girl|Tom Petty|1976|R|CL
Free Fallin'|Tom Petty|1989|R|CL
Mary Jane's Last Dance|Tom Petty|1993|R|CL
I Won't Back Down|Tom Petty|1989|R|CL
Runnin' Down a Dream|Tom Petty|1989|R|CR
Refugee|Tom Petty|1979|R|CR
Born to Run|Bruce Springsteen|1975|R|CL
Dancing in the Dark|Bruce Springsteen|1984|R|CL
Born in the U.S.A.|Bruce Springsteen|1984|R|CL
Thunder Road|Bruce Springsteen|1975|R|CL
Badlands|Bruce Springsteen|1978|R|CR
The River|Bruce Springsteen|1980|R|CL
Hurts So Good|John Mellencamp|1982|R|CR
Jack & Diane|John Mellencamp|1982|R|CL
Summer of '69|Bryan Adams|1984|R|CR
Run to You|Bryan Adams|1984|R|CL
Heaven|Bryan Adams|1984|R|CL
Cuts Like a Knife|Bryan Adams|1983|R|CL
Solsbury Hill|Peter Gabriel|1977|R|CL
Sledgehammer|Peter Gabriel|1986|R|CL
Follow You Follow Me|Genesis|1978|R|CL
Turn It On Again|Genesis|1980|R|CR
Mr. Blue Sky|Electric Light Orchestra|1977|R|CL
Evil Woman|Electric Light Orchestra|1975|R|CL
Band on the Run|Paul McCartney & Wings|1973|R|CL
Jet|Paul McCartney & Wings|1973|R|CR
Live and Let Die|Paul McCartney & Wings|1973|R|CR
Cold Turkey|John Lennon|1969|R|FZ
Instant Karma!|John Lennon|1970|R|CL
My Sweet Lord|George Harrison|1970|R|CL
What Is Life|George Harrison|1970|R|CL
Got My Mind Set on You|George Harrison|1987|R|CL
Baker Street|Gerry Rafferty|1978|R|LD
All Right Now|Free|1970|HR|CR
Wishing Well|Free|1972|HR|CR
Can't Get Enough|Bad Company|1974|HR|CR
Feel Like Makin' Love|Bad Company|1975|HR|CL
Bad Company|Bad Company|1974|HR|CL
Smokin'|Boston|1976|HR|CR
Slow Ride|Foghat|1975|HR|CR
Radar Love|Golden Earring|1973|HR|CR
Hocus Pocus|Focus|1971|HR|CR
Black Betty|Ram Jam|1977|HR|CR
Because the Night|Patti Smith|1978|R|CL
Gloria|Patti Smith|1975|R|CR
Blitzkrieg Bop|Ramones|1976|R|CR
I Wanna Be Sedated|Ramones|1978|R|CR
Sheena Is a Punk Rocker|Ramones|1977|R|CR
Rockaway Beach|Ramones|1977|R|CR
Anarchy in the U.K.|Sex Pistols|1976|R|CR
God Save the Queen|Sex Pistols|1977|R|CR
Pretty Vacant|Sex Pistols|1977|R|CR
London Calling|The Clash|1979|R|CR
Should I Stay or Should I Go|The Clash|1982|R|CR
Rock the Casbah|The Clash|1982|R|CL
Train in Vain|The Clash|1979|R|CL
Complete Control|The Clash|1977|R|CR
Ever Fallen in Love|Buzzcocks|1978|R|CR
Teenage Kicks|The Undertones|1978|R|CR
Another Girl, Another Planet|The Only Ones|1978|R|CR
What Do I Get?|Buzzcocks|1978|R|CR
Alternative Ulster|Stiff Little Fingers|1978|R|CR
Sound and Vision|David Bowie|1977|R|CL
Ashes to Ashes|David Bowie|1980|R|CL
Personal Jesus|Depeche Mode|1989|A|CR
I Feel You|Depeche Mode|1993|A|FZ
Bela Lugosi's Dead|Bauhaus|1979|A|CL
She Sells Sanctuary|The Cult|1985|A|CR
Fire Woman|The Cult|1989|HR|CR
Love Removal Machine|The Cult|1987|HR|CR
Dear Prudence|Siouxsie and the Banshees|1983|A|CL
Cities in Dust|Siouxsie and the Banshees|1985|A|CL
This Corrosion|The Sisters of Mercy|1987|A|CR
Temple of Love|The Sisters of Mercy|1983|A|CR
Add It Up|Violent Femmes|1983|A|CL
Blister in the Sun|Violent Femmes|1983|A|CL
Birdhouse in Your Soul|They Might Be Giants|1990|A|CL
Semi-Charmed Life|Third Eye Blind|1997|A|CR
Jumper|Third Eye Blind|1997|A|CL
Graduate|Third Eye Blind|1997|A|CR
The Middle|Jimmy Eat World|2001|A|CR
Sweetness|Jimmy Eat World|2001|A|CR
Pain|Jimmy Eat World|2004|A|CR
The Reason|Hoobastank|2003|A|CL
Crawling in the Dark|Hoobastank|2001|A|HG
Everything Zen|Bush|1994|A|OD
Interstate Love Song|Stone Temple Pilots|1994|A|CR
Hey Man Nice Shot|Filter|1995|A|HG
Take a Picture|Filter|1999|A|CL
Counting Blue Cars|Dishwalla|1995|A|CR
Low|Cracker|1993|A|CR
Lightning Crashes|Live|1994|A|CL
I Alone|Live|1994|A|OD
All Over You|Live|1994|A|CR
Selling the Drama|Live|1994|A|CL
Closing Time|Semisonic|1998|A|CL
Push|Matchbox Twenty|1996|A|CL
3AM|Matchbox Twenty|1996|A|CL
Unwell|Matchbox Twenty|2002|A|CL
Torn|Natalie Imbruglia|1997|A|CL
One Headlight|The Wallflowers|1996|A|CL
6th Avenue Heartache|The Wallflowers|1996|A|CL
Run-Around|Blues Traveler|1994|A|CL
Two Princes|Spin Doctors|1992|A|CL
Little Miss Can't Be Wrong|Spin Doctors|1991|A|CL
What I Got|Sublime|1996|A|CL
Santeria|Sublime|1996|A|CL
Wrong Way|Sublime|1996|A|CR
Amber|311|2001|A|CL
Down|311|1995|A|HG
Killing Me Softly? skip|x|1996|A|CL
Man of the Hour|Pearl Jam|2003|G|CL
Daughter|Pearl Jam|1993|G|CL
Last Kiss|Pearl Jam|1999|G|CL
# ============ TURKISH ============
Dağlar Dağlar|Barış Manço|1970|T|CL
Gülpembe|Barış Manço|1981|T|CL
Sarı Çizmeli Mehmet Ağa|Barış Manço|1979|T|CL
Alla Beni Pulla Beni|Barış Manço|1976|T|CL
Anlıyorsun Değil mi|Barış Manço|1979|T|CL
Halhal|Barış Manço|1983|T|CL
Kara Sevda|Barış Manço|1985|T|CL
Domates Biber Patlıcan|Barış Manço|1983|T|CL
Nick the Chopper|Barış Manço|1976|T|CR
Ben Bilirim|Barış Manço|1985|T|CL
Bal Böceği|Barış Manço|1988|T|CL
Söyle Zalim Sultan|Barış Manço|1983|T|CL
Kol Düğmeleri|Barış Manço|1967|T|CL
Lambaya Püf De|Barış Manço|1972|T|P
Tamirci Çırağı|Cem Karaca|1978|T|CR
Resimdeki Gözyaşları|Cem Karaca|1969|T|CL
Islak Islak|Cem Karaca|1977|T|CL
Bu Son Olsun|Cem Karaca|1987|T|CL
Namus Belası|Cem Karaca|1987|T|CR
Ceviz Ağacı|Cem Karaca|1978|T|CL
Deniz Üstü Köpürür|Cem Karaca|1978|T|CR
Herkes Gibisin|Cem Karaca|1978|T|CR
Ay Karanlık|Cem Karaca|1974|T|CR
Kara Yılan|Cem Karaca|1973|T|CR
Oy Babo|Cem Karaca|1975|T|CR
Parka|Cem Karaca|1975|T|CL
Beni Siz Delirttiniz|Cem Karaca|1981|T|CR
Cemalim|Erkin Koray|1974|T|FZ
Estarabim|Erkin Koray|1977|T|FZ
Şaşkın|Erkin Koray|1974|T|FZ
Fesuphanallah|Erkin Koray|1976|T|FZ
Anma Arkadaş|Erkin Koray|1967|T|P
Sevince|Erkin Koray|1971|T|P
Yalnızlar Rıhtımı|Erkin Koray|1976|T|CL
Çöpçüler|Erkin Koray|1975|T|FZ
Arap Saçı|Erkin Koray|1976|T|FZ
Krallar|Erkin Koray|1974|T|FZ
Gel Bana|Erkin Koray|1973|T|P
Bi' Şey Yapmalı|Moğollar|1971|T|P
Garip Çoban|Moğollar|1971|T|CL
Alageyik Destanı|Moğollar|1971|T|P
Issızlığın Ortasında|Moğollar|1994|T|CL
Bir Sen Bir de Ben|Moğollar|1994|T|CL
Nerdesin|Bulutsuzluk Özlemi|1986|T|CR
Sözlerimi Geri Alamam|Bulutsuzluk Özlemi|1988|T|CR
Uçtu Uçtu|Bulutsuzluk Özlemi|1990|T|CR
Yaşamaya Mecbursun|Bulutsuzluk Özlemi|1986|T|CR
Acil Demokrasi|Bulutsuzluk Özlemi|1988|T|CR
Ele Güne Karşı|MFÖ|1984|T|CL
Bu Sabah Yağmur Var|MFÖ|1985|T|CL
Sarı Laleler|MFÖ|1985|T|CL
Güllerin İçinden|MFÖ|1984|T|CL
Peki Peki Anladık|MFÖ|1984|T|CL
Yeter ki|Fikret Kızılok|1990|T|CL
Bu Kalp Seni Unutur mu|Fikret Kızılok|1990|T|CL
Zaman Zaman|Fikret Kızılok|1993|T|CL
Sevenler Ağlarmış|3 Hürel|1972|T|P
Ağlarsa Anam Ağlar|3 Hürel|1973|T|P
Canım Kurban|3 Hürel|1974|T|P
Aldırma Gönül|Edip Akbayram|1977|T|CL
Hasretinle Yandı Gönlüm|Edip Akbayram|1974|T|P
Bir|Pentagram|1996|M|HG
Gündüz Gece|Pentagram|1996|M|CL
Şeytan Bunun Neresinde|Pentagram|1996|M|HG
Anatolia|Pentagram|1997|M|HG
Fly Forever|Pentagram|1997|M|HG
Lions in a Cage|Pentagram|1997|M|HG
Sil Baştan|Şebnem Ferah|2001|T|OD
Bu Aşk Fazla Sana|Şebnem Ferah|1996|T|CR
Mayın Tarlası|Şebnem Ferah|2001|T|HG
Sigara|Şebnem Ferah|2001|T|CL
Vazgeçtim Dünyadan|Şebnem Ferah|1999|T|OD
Fırtına|Şebnem Ferah|1999|T|HG
Yalnız|Şebnem Ferah|1996|T|CL
Ben Şarkımı Söylerken|Şebnem Ferah|2005|T|CL
Delgeç|Şebnem Ferah|2005|T|HG
Can Kırıkları|Şebnem Ferah|2003|T|CL
Papatya|Teoman|1996|T|CL
İstanbul'da Sonbahar|Teoman|2000|T|CL
Paramparça|Teoman|2001|T|CL
Gemiler|Teoman|1998|T|CL
Serseri|Teoman|2000|T|CR
Rüzgar Gülü|Teoman|1998|T|CL
Renkli Rüyalar Oteli|Teoman|2006|T|CL
İki Yabancı|Teoman|2001|T|CL
Limanında|Teoman|1996|T|CL
Hayalperest|Teoman|2011|T|CL
Çoban Yıldızı|Teoman|1996|T|CL
Uykusuz Her Gece|Teoman|1996|T|CL
Tek Başına Dans|Teoman|1998|T|CL
Senden Önce Senden Sonra|Teoman|2004|T|CL
Her Şeyi Yak|Duman|1999|T|OD
Senden Daha Güzel|Duman|2002|T|CR
Bu Akşam|Duman|1999|T|CL
Belki Alışman Lazım|Duman|2002|T|CL
Köprüaltı|Duman|2002|T|CL
Aman Aman|Duman|2006|T|CR
Elleri Ellerime|Duman|2006|T|CL
Sor Bana Pişman mıyım|Duman|2006|T|OD
Öyle Dertli|Duman|2009|T|CL
Melankoli|Duman|2009|T|CL
Halimiz Duman|Duman|2013|T|CR
İyi de Bana Ne|Duman|2013|T|CR
Dibine Kadar|Duman|2009|T|CR
Balık|Duman|2013|T|CR
Yürek|Duman|1999|T|OD
Cambaz|Mor ve Ötesi|2004|T|CR
Bir Derdim Var|Mor ve Ötesi|2004|T|CR
Sevda Çiçeği|Mor ve Ötesi|2004|T|CL
Deli|Mor ve Ötesi|2004|T|CR
Uyan|Mor ve Ötesi|2004|T|CR
Ölüm|Mor ve Ötesi|2004|T|CL
Bisiklet|Mor ve Ötesi|1996|T|CL
Aşk İçinde|Mor ve Ötesi|2006|T|CR
Dursun Zaman|maNga|2009|T|HG
We Could Be the Same|maNga|2010|T|HG
Bir Kadın Çizeceksin|maNga|2004|T|HG
Cevapsız Sorular|maNga|2009|T|HG
Beni Benimle Bırak|maNga|2009|T|HG
Dünyanın Sonuna Doğmuşum|maNga|2006|T|HG
Fly to Stay Alive|maNga|2009|T|HG
Libido|maNga|2004|T|HG
Ben Böyleyim|Athena|2002|T|CR
Senden Benden Bizden|Athena|2004|T|CR
Öpücem|Athena|2004|T|CR
Arsız Gönül|Athena|2005|T|CR
Yalan|Athena|2002|T|CR
Tam Zamanı Şimdi|Athena|2002|T|CR
Her Şey Yolunda|Athena|2000|T|CR
Aşk Nereden Nereye|Gripin|2007|T|CR
Sensiz Olmaz|Gripin|2005|T|CR
Beş|Gripin|2007|T|CR
Durma Yağmur Durma|Gripin|2010|T|CL
Böyle Kahpedir Dünya|Gripin|2004|T|CR
Afili Yalnızlık|Emre Aydın|2006|T|CL
Belki Bir Gün Özlersin|Emre Aydın|2008|T|CL
Git|Emre Aydın|2006|T|CR
Hoşçakal|Emre Aydın|2010|T|CL
Kağıt Evler|Emre Aydın|2008|T|CL
Bu Kez Anladım|Emre Aydın|2010|T|CR
Dipteyim Sondayım Depresyondayım|Emre Aydın|2006|T|CR
Belki Üstümüzden Bir Kuş Geçer|Yüksek Sadakat|2006|T|CR
Haydi Gel İçelim|Yüksek Sadakat|2006|T|CR
Kafile|Yüksek Sadakat|2006|T|CR
Aşk Durdukça|Yüksek Sadakat|2011|T|CL
Beni Bırakma|Feridun Düzağaç|2004|T|CL
Alev Alev|Feridun Düzağaç|2004|T|CR
F.D.|Feridun Düzağaç|2004|T|CL
Şehir|Feridun Düzağaç|1996|T|CL
Yalnız|Pilli Bebek|1998|T|CL
Kumdan Kaleler|Pilli Bebek|2003|T|CL
Uzaylı|Pilli Bebek|1998|T|CL
Yıldızların Altında|Kargo|1998|T|CR
Sen Bir Meleksin|Kargo|2000|T|CL
Ay Işığı|Kargo|1998|T|CR
Sevmek Zor|Kargo|1996|T|CR
Segah|Kargo|2002|T|CL
50/50|Redd|2007|T|CR
Meleğim|Redd|2009|T|CR
Ölüyorum|Hayko Cepkin|2005|T|HG
Yalnız Kalsın|Hayko Cepkin|2007|T|HG
Sakin Olmam Lazım|Hayko Cepkin|2007|T|HG
Melekler|Hayko Cepkin|2010|T|CL
Fırtınam|Hayko Cepkin|2007|T|HG
Ben Ne Yangınlar Gördüm|Zakkum|2013|T|CR
Anlatamıyorum|Zakkum|2011|T|CL
Mey|Model|2009|T|CL
Pembe Mezarlık|Model|2009|T|CR
Buzdan Şato|Model|2011|T|CL
Bir Melek Vardı|Model|2009|T|CL
Sarı Kurdeleler|Model|2011|T|CL
Antidepresan|Model|2013|T|CR
Hayde|Seksendört|2005|T|CR
Söyle|Seksendört|2008|T|CL
Dön Bak Dünyaya|Pinhani|2006|T|CL
Ne Güzel Güldün|Pinhani|2009|T|CL
Beni Al|Pinhani|2006|T|CL
İstanbul'da|Pinhani|2006|T|CL
Koca Yaşlı Şişko Dünya|Adamlar|2016|T|CR
Orada Ortada|Adamlar|2014|T|CR
Ah Benim Hayatım|Adamlar|2016|T|CL
Zurnanın Zırt Dediği Yer|Adamlar|2012|T|CR
Olmuyo|Büyük Ev Ablukada|2016|T|CR
Fırtınayt|Büyük Ev Ablukada|2016|T|CR
İnsanlar Evlerde|Son Feci Bisiklet|2014|T|CL
Amerikan Meyhanesi|Son Feci Bisiklet|2016|T|CL
Bihaber|Dolu Kadehi Ters Tut|2018|T|CR
Ahtapotun Bahçesi|Madrigal|2017|T|CL
Goca Dünya|Altın Gün|2018|T|P
Süpürgesi Yoncadan|Altın Gün|2018|T|P
Tatlı Dile Güler Yüze|Altın Gün|2019|T|P
Yolcu|Altın Gün|2019|T|P
Dönersen Islık Çal|Manuş Baba|2017|T|CL
Eteği Belinde|Manuş Baba|2017|T|CL
Elfida|Haluk Levent|2007|T|CL
Yollarda|Haluk Levent|1996|T|CR
Zifiri|Haluk Levent|2013|T|CL
Bana Ne|Ogün Sanlısoy|2000|T|CR
Gidiyorum|Ogün Sanlısoy|2004|T|CL
Kül|Cem Adrian|2006|T|CL
Yaz Gazeteci Yaz|Selda Bağcan|1976|T|P
İnce İnce Bir Kar Yağar|Selda Bağcan|1975|T|P
Yuh Yuh|Selda Bağcan|1976|T|P
Gurbet|Özdemir Erdoğan|1972|T|CL
Sen Benim Şarkılarımsın|Gündoğarken|1988|T|CL
Aşk Yeniden|Yeni Türkü|1985|T|CL
Olmasa Mektubun|Yeni Türkü|1985|T|CL
Bir Sana Bir de Bana|BaBa ZuLa|2005|T|P
Dünya|Kesmeşeker|1996|T|CR
Sarhoş|Kıraç|1999|T|CR
Endamın Yeter|Kıraç|2001|T|CL
Ateşteyiz|Çilekeş|2005|T|OD
Karanlık Yollar|Vega|1999|T|CL
Tren|Vega|2003|T|CL
"""

GENRES = {"R": "Rock", "HR": "Hard Rock", "M": "Metal", "G": "Grunge", "B": "Blues Rock",
          "A": "Alternative", "F": "Funk Rock", "P": "Psychedelic", "T": "Anadolu Rock"}
CHARS = {"CL": "Clean", "CR": "Crunch", "OD": "Overdrive", "HG": "High Gain", "FZ": "Fuzz", "LD": "Lead"}

AMPS_VINTAGE = ["Marshall Super Lead (Plexi)", "Fender Twin Reverb", "Vox AC30", "Hiwatt DR103", "Fender Bassman"]
AMPS = {
    "Rock": ["Fender Twin Reverb", "Vox AC30", "Marshall JCM800", "Fender Deluxe Reverb"],
    "Hard Rock": ["Marshall JCM800", "Marshall Super Lead (Plexi)", "Marshall JCM2000"],
    "Metal": ["Mesa/Boogie Dual Rectifier", "Peavey 5150", "Marshall JCM800", "EVH 5150 III"],
    "Grunge": ["Fender Twin Reverb", "Mesa/Boogie Studio .22", "Marshall JCM900", "Vox AC30"],
    "Blues Rock": ["Fender Bassman", "Fender Deluxe Reverb", "Marshall Bluesbreaker", "Fender Super Reverb"],
    "Alternative": ["Fender Twin Reverb", "Vox AC30", "Orange Rockerverb", "Marshall JCM900"],
    "Funk Rock": ["Fender Twin Reverb", "Marshall JCM800", "Fender Super Reverb"],
    "Psychedelic": ["Marshall Super Lead (Plexi)", "Vox AC30", "Fender Twin Reverb"],
    "Anadolu Rock": ["Vox AC30", "Fender Twin Reverb", "Orange OR120", "Marshall Super Lead (Plexi)"],
}
GUITARS = {
    "Rock": [("Fender Stratocaster", "Bridge single-coil"), ("Fender Telecaster", "Bridge single-coil"), ("Gibson Les Paul", "Bridge humbucker"), ("Gibson ES-335", "Neck humbucker")],
    "Hard Rock": [("Gibson Les Paul", "Bridge humbucker"), ("Gibson SG", "Bridge humbucker"), ("Fender Stratocaster", "Bridge single-coil")],
    "Metal": [("Gibson Les Paul", "Bridge humbucker"), ("ESP Eclipse (EMG 81)", "Bridge humbucker (active)"), ("Ibanez RG", "Bridge humbucker"), ("Jackson Soloist", "Bridge humbucker")],
    "Grunge": [("Fender Mustang", "Bridge humbucker"), ("Fender Jaguar", "Bridge single-coil"), ("Gibson Les Paul", "Bridge humbucker")],
    "Blues Rock": [("Fender Stratocaster", "Neck single-coil"), ("Gibson Les Paul", "Neck humbucker"), ("Gibson ES-335", "Neck humbucker")],
    "Alternative": [("Fender Jazzmaster", "Bridge single-coil"), ("Fender Telecaster", "Bridge single-coil"), ("Gibson SG", "Bridge humbucker"), ("Fender Stratocaster", "Middle + bridge (position 2)")],
    "Funk Rock": [("Fender Stratocaster", "Neck & middle positions"), ("Fender Telecaster", "Bridge single-coil")],
    "Psychedelic": [("Fender Stratocaster", "Bridge single-coil"), ("Gibson SG", "Bridge humbucker")],
    "Anadolu Rock": [("Fender Stratocaster", "Neck single-coil"), ("Gibson SG", "Bridge humbucker"), ("Fender Jazzmaster", "Bridge single-coil")],
}
# gain, bass, mid, treble, presence, reverb
SETTINGS = {
    "Clean": (2.5, 5.0, 5.0, 5.5, 4.0, 3.5),
    "Crunch": (5.5, 5.0, 5.5, 6.0, 5.0, 1.5),
    "Overdrive": (6.5, 5.0, 5.5, 6.0, 5.0, 2.0),
    "High Gain": (8.0, 6.0, 3.5, 6.5, 6.0, 0.0),
    "Fuzz": (5.5, 5.5, 5.0, 6.0, 5.0, 2.0),
    "Lead": (7.0, 5.0, 6.5, 6.0, 5.5, 2.5),
}
TONE_NAMES = {"Clean": "Clean Tone", "Crunch": "Main Riff", "Overdrive": "Main Tone",
              "High Gain": "Main Riff", "Fuzz": "Fuzz Tone", "Lead": "Lead Tone"}
PEDAL_SETS = {
    "Clean": [
        [],
        [("MXR Dyna Comp", "compressor", [("Output", 6.0), ("Sensitivity", 5.0)], "Evens out the attack for a smooth clean.")],
        [("Boss CE-2 Chorus", "chorus", [("Rate", 3.0), ("Depth", 5.0)], "Light shimmer over the clean base.")],
    ],
    "Crunch": [
        [],
        [("Ibanez Tube Screamer", "overdrive", [("Drive", 3.5), ("Tone", 5.0), ("Level", 6.5)], "Pushes the amp's own breakup harder.")],
        [("Boss SD-1", "overdrive", [("Drive", 4.0), ("Tone", 5.0), ("Level", 6.0)], "Mild push for the dirty rhythm parts.")],
    ],
    "Overdrive": [
        [("Ibanez Tube Screamer", "overdrive", [("Drive", 5.5), ("Tone", 5.0), ("Level", 6.0)], "The core drive — amp set on the edge of breakup.")],
        [("Boss BD-2 Blues Driver", "overdrive", [("Gain", 5.5), ("Tone", 5.5), ("Level", 6.0)], "Open, amp-like drive that follows pick attack.")],
    ],
    "High Gain": [
        [("Ibanez Tube Screamer", "boost", [("Drive", 1.0), ("Tone", 5.0), ("Level", 8.5)], "Nearly-clean boost that tightens the low end."),
         ("Noise Gate", "eq", [("Threshold", 5.0)], "Keeps the palm-muted riffs tight and quiet.")],
        [("Maxon OD808", "boost", [("Drive", 1.5), ("Tone", 5.0), ("Level", 8.0)], "Tightening boost in front of the high-gain channel.")],
    ],
    "Fuzz": [
        [("EHX Big Muff Pi", "fuzz", [("Sustain", 6.5), ("Tone", 4.5), ("Volume", 6.0)], "The wall-of-fuzz core of the tone.")],
        [("Dunlop Fuzz Face", "fuzz", [("Fuzz", 7.5), ("Volume", 6.5)], "Clean up with the guitar's volume knob.")],
    ],
    "Lead": [
        [("Ibanez Tube Screamer", "overdrive", [("Drive", 5.0), ("Tone", 5.5), ("Level", 7.0)], "Saturation and sustain for the lead lines."),
         ("Analog Delay", "delay", [("Time", 4.0), ("Repeats", 3.5), ("Mix", 3.0)], "Space around the solo — repeats tucked under.")],
        [("Boss DS-1", "distortion", [("Dist", 6.0), ("Tone", 5.0), ("Level", 6.0)], "Focused distortion for singing leads."),
         ("Digital Delay", "delay", [("Time", 4.5), ("Repeats", 3.0), ("Mix", 2.5)], "Adds depth to held notes.")],
    ],
}
NOTES = {
    "Clean": ["Keep the pick attack light and let the chords breathe.",
              "Roll the guitar volume back slightly for extra sparkle.",
              "Neck-position warmth carries the melody — dig in only for accents."],
    "Crunch": ["Set gain so the tone cleans up when you pick softly and bites when you dig in.",
               "Big open chords, let them ring — the amp does the work.",
               "Palm-mute the verses lightly, open up for the chorus."],
    "Overdrive": ["The drive stays smooth — most of the character is the amp on the edge of breakup.",
                  "Ride the guitar volume between rhythm and lead levels.",
                  "Mid-forward drive keeps the riff clear in a band mix."],
    "High Gain": ["Tight, all-downstroke picking keeps the riff aggressive.",
                  "Scooped mids sound huge alone — add mids back on stage to cut through.",
                  "Keep the noise gate fast so palm mutes stay percussive."],
    "Fuzz": ["Ride the guitar volume knob: full up for the riff, backed off to clean up.",
             "Fuzz into a loud, mostly clean amp — the speaker breakup is part of the sound.",
             "Thick fuzz sustains forever; mute the strings you're not playing."],
    "Lead": ["Take your time with the bends — every note counts.",
             "Sustain comes from the amp working hard, not just the pedal.",
             "Add a touch more delay for the held notes at the top of the solo."],
}

TRANSLIT = str.maketrans("çğıöşüÇĞİÖŞÜâîûÂÎÛ", "cgiosuCGIOSUaiuAIU")


def h(s):
    return int(hashlib.md5(s.encode("utf-8")).hexdigest(), 16)


def jitter(base, seed, spread=1.0):
    v = base + ((seed % 21) - 10) / 10.0 * spread
    return max(0.0, min(10.0, round(v * 2) / 2))


def slugify(title, artist):
    s = (title + " " + artist).translate(TRANSLIT).lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:80] or "song"


def norm(s):
    return re.sub(r"[^a-z0-9]+", " ", s.translate(TRANSLIT).lower()).strip()


def itunes_artist_songs(artist, country):
    """One request per artist (not per song) to stay under the rate limit."""
    params = urllib.parse.urlencode({
        "term": artist, "media": "music", "entity": "song",
        "attribute": "artistTerm", "limit": 200, "country": country,
    })
    url = "https://itunes.apple.com/search?" + params
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "ToneAmp-Seed/1.0"})
            with urllib.request.urlopen(req, timeout=20) as r:
                if r.status == 200:
                    return json.loads(r.read().decode("utf-8")).get("results", [])
        except Exception as e:
            # 403 = throttled; long backoff before retrying
            print(f"  retry {artist}: {e}", flush=True)
            time.sleep(45 if "403" in str(e) else 6)
    return []


def build_song(title, artist, year, gcode, ccode):
    genre = GENRES.get(gcode, "Rock")
    character = CHARS.get(ccode, "Crunch")
    if ccode == "P":
        character = "Fuzz"
    sid = slugify(title, artist)
    seed = h(sid)
    amp_pool = AMPS_VINTAGE if year < 1975 and genre != "Metal" else AMPS.get(genre, AMPS["Rock"])
    amp = amp_pool[seed % len(amp_pool)]
    gpool = GUITARS.get(genre, GUITARS["Rock"])
    guitar, pickup = gpool[(seed // 7) % len(gpool)]
    g, b_, m, t, p, r = SETTINGS[character]
    settings = {
        "gain": jitter(g, seed), "bass": jitter(b_, seed // 3), "mid": jitter(m, seed // 5),
        "treble": jitter(t, seed // 11), "presence": jitter(p, seed // 13), "reverb": jitter(r, seed // 17, 0.5),
    }
    chosen = PEDAL_SETS[character][(seed // 19) % len(PEDAL_SETS[character])]
    pedals = [{
        "name": pname, "type": ptype,
        "controls": [{"name": cn, "value": jitter(cv, seed // 23)} for cn, cv in controls],
        "note": pnote,
    } for (pname, ptype, controls, pnote) in chosen]
    notes = NOTES[character][(seed // 29) % len(NOTES[character])]
    return sid, {
        "id": sid, "title": title, "artist": artist, "album": "",
        "year": year, "genre": genre,
        "tones": [{
            "id": sid + "-t0", "name": TONE_NAMES[character], "amp": amp,
            "character": character, "settings": settings,
            "guitar": guitar, "pickup": pickup, "pedals": pedals, "notes": notes,
        }],
    }


def main():
    out_path = sys.argv[1]
    fetch_artwork = "--no-artwork" not in sys.argv

    lines = [l.strip() for l in SONGS.strip().splitlines()
             if l.strip() and not l.strip().startswith("#") and "skip|" not in l]
    print(f"songs in list: {len(lines)}", flush=True)

    songs, seen = [], set()
    by_artist = {}
    for line in lines:
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 5:
            continue
        title, artist, year, gcode, ccode = parts[0], parts[1], int(parts[2]), parts[3], parts[4]
        sid, song = build_song(title, artist, year, gcode, ccode)
        if sid in seen:
            continue
        seen.add(sid)
        songs.append(song)
        country = "TR" if gcode == "T" else "US"
        by_artist.setdefault((artist, country), []).append(song)

    matched = 0
    if fetch_artwork:
        # Checkpointed fetch: one cache entry per artist, written to disk
        # after every request so a killed run resumes where it stopped.
        cache_path = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else None
        cache = {}
        if cache_path and os.path.exists(cache_path):
            with open(cache_path, encoding="utf-8") as f:
                cache = json.load(f)
        artists = list(by_artist.keys())
        pending = [(a, c) for (a, c) in artists if f"{a}|{c}" not in cache]
        print(f"unique artists: {len(artists)}, cached: {len(artists) - len(pending)}, pending: {len(pending)}", flush=True)
        for i, (artist, country) in enumerate(pending):
            results = itunes_artist_songs(artist, country)
            na = norm(artist)
            entry = {}
            for res in results:
                ra = norm(res.get("artistName", ""))
                if na and (na in ra or ra in na):
                    rt = norm(res.get("trackName", ""))
                    if rt and rt not in entry:
                        a100 = res.get("artworkUrl100")
                        entry[rt] = {
                            "art": a100.replace("100x100", "600x600") if a100 else None,
                            "album": res.get("collectionName") or "",
                        }
            cache[f"{artist}|{country}"] = entry
            if cache_path:
                with open(cache_path, "w", encoding="utf-8") as f:
                    json.dump(cache, f, ensure_ascii=False)
            if (i + 1) % 10 == 0:
                print(f"fetched {i + 1}/{len(pending)}", flush=True)
            time.sleep(2.5)

        # Apply the cache to every song
        for (artist, country), slist in by_artist.items():
            entry = cache.get(f"{artist}|{country}", {})
            keys = list(entry.keys())
            for song in slist:
                nt = norm(song["title"])
                best = entry.get(nt)
                if best is None:
                    for rt in keys:
                        if nt and (nt in rt or rt in nt):
                            best = entry[rt]
                            break
                if best:
                    matched += 1
                    song["album"] = best["album"]
                    if best["art"]:
                        song["artworkURL"] = best["art"]

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(songs, f, ensure_ascii=False)
    print(f"DONE: {len(songs)} songs written, artwork matched for {matched}", flush=True)


if __name__ == "__main__":
    main()
