
use inc::Module::Install;

name            ('Kwiki-MindMap');
abstract        ("A Kwiki plugin that displays what's on your mind");
author          ('Kang-min Liu (gugod@gugod.org)');
license         ('perl');
version_from    ('lib/Kwiki/MindMap.pm');
requires        ('Kwiki' => 0.31);

&WriteAll;

