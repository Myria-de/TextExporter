# Options -- POSIX compatible options parsing
# Port of PERL GetOpt::Long.pm, GetoptLong.pm by Johan Vromans
# Port author: Tim Colles <timc@dai.ed.ac.uk>

# 1.01 Fixes to '+' flag handling, contributed by Sean Laurent,
#   Sonic Foundry, Inc., <slaurent@sonicfoundry.com>
# 1.0 First Release

################ Copyright ################

# This program is Copyright 1990,1998 by Johan Vromans.
# This port is Copyright 2001 by Tim Colles.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# If you do not have a copy of the GNU General Public License write to
# the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, 
# MA 02139, USA.

from os import environ, sys
import types
import re
from string import split, join

VERSION = '1.01'
FROM_VERSION = '2.17'

class OptionClass:
  def __init__(self, **args):
    for (key, value) in args.items():
      setattr(self, key, value)

def ConfigDefaults():
  global genprefix, autoabbrev, bundling, getopt_compat, order, \
    debug, error, ignorecase, passthrough, myOptions
  if environ.has_key('POSIXLY_CORRECT'):
    genprefix = '(--|-)'
    autoabbrev = 0
    bundling = 0
    getopt_compat = 0
    order = REQUIRE_ORDER
  else:
    genprefix = '(--|-|\\+)'
    autoabbrev = 1
    bundling = 0
    getopt_compat = 1
    order = PERMUTE
  debug = 0
  error = 0
  ignorecase = 1
  passthrough = 0
  myOptions = OptionClass() # for global vars!

def Configure(*options):
  global autoabbrev, getopt_compat, ignorecase, bundling, order, \
    passthrough, genprefix, debug, myOptions
  for opt in options:
    if type(opt) == types.InstanceType:
      myOptions = opt
    else:
      opt = opt.lower()
      action = 1
      pm = re.search('^no_?(.*)$',opt)
      if pm:
        action = 0
        opt = pm.group(1)
      if opt == 'default' or opt == 'defaults':
        if action:
          ConfigDefaults()
      elif opt == 'auto_abbrev' or opt == 'autoabbrev':
        autoabbrev = action
      elif opt == 'getopt_compat':
        getopt_compat = action
      elif opt == 'ignorecase' or opt == 'ignore_case':
        ignorecase = action
      elif opt == 'ignore_case_always':
        if action:
          ignorecase = 2
        else:
          ignorecase = 0
      elif opt == 'bundling':
        bundling = action
      elif opt == 'bundling_override':
        if action:
          bundling = 2
        else:
          bundling = 0
      elif opt == 'require_order':
        if action:
          order = REQUIRE_ORDER
        else:
          order = PERMUTE
      elif opt == 'permute':
        if action:
          order = PERMUTE
        else:
          order = REQUIRE_ORDER
      elif opt == 'pass_through' or opt == 'passthrough':
        passthrough = action
      elif opt == 'debug':
        debug = action
      else:
        pm = re.search('^prefix=(.+)$',opt)
        if pm:
          genprefix = pm.group(1)
          genprefix = '(' + re.escape(genprefix) + ')'
          try:
            pm = re.search(genprefix,'')
          except:
            print 'Invalid pattern "'+genprefix+'"'
        else:
          pm = re.search('^prefix_pattern=(.+)$',opt)
          if pm:
            genprefix = pm.group(1)
            if not re.search('^\(.*\)$',genprefix):
              genprefix = '(' + genprefix + ')'
            try:
              pm = re.search(genprefix,'')
            except:
              print 'Invalid pattern "'+genprefix+'"'
          else:
            print 'Unknown config parameter "'+opt+'"'

def GetOptions(*options):
  global genprefix, error

  optionlist = list(options)    # local copy of the option descriptions
  argend = '--'                 # option list terminator
  opctl = {}                    # table of arg.specs (long and abbrevs)
  bopctl = {}                   # table of arg.specs (bundles)
  aliases = {}                  # alias table
  ret = []                      # accum for non-options
  linkage = {}                  # linkage
  userlinkage = None            # user supplied HASH
  opt = None                    # current option
  optref = None                 # current option reference
#  opctl = None                  # the possible long option names
# above conflicts, used as array type in Perl

  error = ''

  if debug:
    print 'Options '+VERSION+'\n'\
      +'ARGV: ('+join(sys.argv,', ')+')\n'\
		  +'autoabbrev='+`autoabbrev`\
		  +',bundling='+`bundling`\
		  +',getopt_compat='+`getopt_compat`\
		  +',order='+`order`+',\n'\
		  +'ignorecase='+`ignorecase`\
		  +',passthrough='+`passthrough`\
		  +',genprefix="'+`genprefix`+'".'\

  userlinkage = None
  if type(optionlist[0]) == types.DictionaryType:
    userlinkage = optionlist.pop(0)
    if debug: print '=> user linkage: '+userlinkage

  while len(optionlist) > 0:
    opt = optionlist.pop(0)
    if type(opt) == types.TupleType:
      opt, optref = opt
    else:
      optref = None

    pm = re.search('^'+genprefix+'+(.*)$',opt)
    if pm: opt = opt[pm.end(1):]

    if opt == '<>':
      if userlinkage != None and userlinkage.has_key(opt):
        optref = userlinkage[opt]
      if type(optref) != types.FunctionType:
        error += 'Option spec <> requires a reference to a subroutine'
        continue
      linkage['<>'] = optref
      continue

    pm = re.search(r'^((\w+[-\w]*)(\|(\?|\w[-\w]*)?)*)?([!~+]|[=:][infse][@%]?)?$',opt)
    if not pm:
      error += 'Error in option spec: "'+opt+'"'
      continue
    ( o, c ) = pm.group(1,5)
    if c == None:
      c = ''
    a = None

    if o == None:
      o = ''
      opctl[o] = c
    else:
      oa = split(o,'|')
      o = oa[0]
      if o != o.lower():
        a = o
      if ignorecase > 1 \
        or (ignorecase and ((bundling and len(o) > 1) or not bundling)):
        o = o.lower()
# We differ from the Perl here - in the Perl it lowercases 'o' and then
# never seems to use it (just resets 'o' to 'linko' value, unlowercased, so
# the lowercase statement in Perl is redundant) - so here we have shifted
# the 'linko' copy until AFTER the lowercasing of 'o'
      linko = o
      for o in oa:
        if bundling and len(o) == 1:
          if ignorecase > 1:
            o = o.lower()
          if c == '!':
            opctl['no'+o] = c
            print "Warning: Ignoring '!' modifier for short option"+o
            c = ''
          opctl[o] = bopctl[o] = c
        else:
          if ignorecase:
            o = o.lower()
          if c == '!':
            opctl['no'+o] = c
            c = ''
          opctl[o] = c
        if a != None:
          aliases[o] = a
        else:
          a = o
      o = linko

    if userlinkage != None:
      if optref == None:
        if userlinkage.has_key(o):
          optref = userlinkage[o]
          if debug:
            print '=> found userlinkage for "'+o+'": '+optref
        else:
          continue

    if optref != None:
      if type(optref) == types.StringType:
        if debug:
          print '=> link "'+o+'" to myOptions.'+optref
        linkage[o] = 'myOptions.'+optref
        exec linkage[o]+' = None'
      else:
# Can't find a way to get the list/dict 'name' out here, works okay
# for a function though
        if debug:
          print '=> link "'+o+'" to '+`optref`
        if type(optref) == types.FunctionType:
          linkage[o] = optref
        elif type(optref) == types.ListType:
          linkage[o] = optref
# These don't seem right, ie. if missing '@' or empty string want to add
# the '@' - below (from Perl) doesn't add '@' if its an empty string?
          if opctl[o] != '' and not re.search(r'\@$',opctl[o]):
            opctl[o] += '@'
          if bundling and bopctl.has_key(o) and bopctl[o] != '' \
            and not re.search(r'\@$',bopctl[o]):
            bopctl[o] += '@'
        elif type(optref) == types.DictionaryType:
          linkage[o] = optref
# These don't seem right, ie. if missing '%' or empty string want to add
# the '%' - below (from Perl) doesn't add '%' if its an empty string?
          if opctl[o] != '' and not re.search(r'\%$',opctl[o]):
            opctl[o] += '%'
          if bundling and bopctl.has_key(o) and bopctl[o] != '' \
            and not re.search(r'\%$',bopctl[o]):
            bopctl[o] += '%'
        else:
          error += 'Invalid option linkage for "'+opt+'"'
    else:
      ov = o
      ov = re.sub('\W','_',ov)
      linkage[o] = 'myOptions.'+ov
      if re.search('@',c):
        if debug:
          print '=> link "'+o+'" to myOptions.'+ov+'[]'
        exec linkage[o]+' = []'
      elif re.search('%',c):
        if debug:
          print '=> link "'+o+'" to myOptions.'+ov+'{}'
        exec linkage[o]+' = {}'
        print linkage[o]
      else:
        if debug:
          print '=> link "'+o+'" to myOptions.'+ov
        if (None == getattr(myOptions,o,None)):
          exec linkage[o]+' = None'

  if error:
    return 0

  error = 0

  opctla = opctl.keys()
  if autoabbrev:
    opctla.sort()

  if debug:
    arrow = '=> '
    for k in opctla:
      v = opctl[k]
      print arrow+'opctl["'+k+'"] = "'+v+'"'
      arrow = '   '
    arrow = '=> '
    for k in bopctl.keys():
      v = bopctl[k]
      print arrow+'bopctl["'+k+'"] = "'+v+'"'
      arrow = '   '

  while len(sys.argv) > 0:

    opt = sys.argv.pop(0)
    if debug:
      print '=> option "'+opt+'"'

    if opt == argend:
      if order == PERMUTE:
        sys.argv.extend(ret)
      return not error

    tryopt = opt
    ( found, opt, arg, dsttype, incr, key ) = \
      FindOption(genprefix,argend,opt,opctl,bopctl,opctla,aliases)

    if found:
      if opt == None:
        continue
      if arg != None:
        if aliases.has_key(opt):
          opt = aliases[opt]
        if linkage.has_key(opt):
          if debug:
            print '=> ref(L['+opt+']) -> '+`linkage[opt]`
          if dsttype == 's':
            carg = arg
          elif dsttype == 'f':
            carg = float(arg)
          else:
            carg = int(arg)
          if type(linkage[opt]) == types.ListType or \
            ( type(linkage[opt]) == types.StringType and \
              type(eval(linkage[opt])) == types.ListType ):
            if debug:
              print '=> L['+opt+'].append('+`arg`+')'
            if type(linkage[opt]) == types.ListType:
              linkage[opt].append(carg)
            else:
              exec linkage[opt]+'.append(carg)'
          elif type(linkage[opt]) == types.DictionaryType or \
            ( type(linkage[opt]) == types.StringType and \
              type(eval(linkage[opt])) == types.DictionaryType ):
            if debug:
              print '=> L['+opt+']['+key+'] = '+`arg`
            if type(linkage[opt]) == types.DictionaryType:
              linkage[opt][key] = carg
            else:
              exec linkage[opt]+'[key] = carg'
          elif type(linkage[opt]) == types.FunctionType or \
            ( type(linkage[opt]) == types.StringType and \
              type(eval(linkage[opt])) == types.FunctionType ):
            if debug:
              print '=> L['+opt+']("'+opt+'",'+`arg`+')'
            if type(linkage[opt]) == types.FunctionType:
              linkage[opt](opt,carg)
            else:
              exec linkage[opt]+'(opt,carg)'
          elif type(linkage[opt]) == types.StringType:
            if incr:
              if debug:
                print '=> L['+opt+'] += '+`arg`
              if eval(linkage[opt]+'==None'):
                exec linkage[opt]+' = carg'
              else:
                exec linkage[opt]+' += carg'
            else:
              if debug:
                print '=> L['+opt+'] = '+`arg`
              exec linkage[opt]+' = carg'
          else:
# PERL has fatal error here
            pass
        elif dsttype == '@':
          if userlinkage[opt] == None:
            if debug:
              print '=> L['+opt+'] = [ '+`arg`+' ]'
            userlinkage[opt] = [ arg ]
          else:
            if debug:
              print '=> L['+opt+'].append('+`arg`+')'
            userlinkage[opt].append(arg)
        elif dsttype == '%':
          if userlinkage[opt] == None:
            if debug:
              print '=> L['+opt+'] = { '+key+' : '+`arg`+' }'
            userlinkage[opt] = { key : arg }
          else:
            if debug:
              print '=> L['+opt+']['+key+'] = '+`arg`
            userlinkage[opt][key] = arg
        else:
          if dsttype == 's':
            carg = arg
          elif dsttype == 'f':
            carg = float(arg)
          else:
            carg = int(arg)
          if incr:
            if debug:
              print '=> L['+opt+'] += '+`arg`
            if eval(userlinkage[opt]+'==None'):
              exec userlinkage[opt]+' += carg'
            else:
              exec userlinkage[opt]+' = carg'
          else:
            if debug:
              print '=> L['+opt+'] = '+`arg`
            exec userlinkage[opt]+' = carg'
    elif order == PERMUTE:
      cb = None
      if linkage.has_key('<>'):
        cb = linkage['<>']
      if cb != None:
        cb(tryopt)
      else:
        if debug:
          print '=> saving "'+tryopt+'" (not an option, may permute)'
        ret.insert(0,tryopt)
      continue
    else:
      sys.argv.insert(0,tryopt)
      return not error

  if order == PERMUTE:
    if len(ret) > 0:
      if debug:
        print '=> restoring "'+join(ret,'" "')+'"'
      sys.argv.extend(ret)

  return not error

def FindOption(prefix,argend,opt,opctl,bopctl,names,aliases):
  global error
  if debug:
    print '=> find "'+opt+'", prefix="'+prefix+'"'

  key = None
  arg = None

  pm = re.search('^'+prefix+'(.*)$',opt)
  if not pm: return(0,None,None,None,None,None)

  opt = opt[pm.end(1):]
  starter = pm.group(1)

  if debug: print '=> split "'+starter+'"+"'+opt+'"'

  optarg = None
  rest = None

  if starter == '--' or (getopt_compat and not bundling):
    pm = re.search('^([^=]+)=(.*)$',opt)
    if pm:
      opt = pm.group(1)
      optarg = pm.group(2)
      if debug:
        print '=> option "'+opt+'", optarg = "'+optarg+'"'

  tryopt = opt
  optbl = opctl
  opttype = None
  dsttype = ''
  incr = 0

  if bundling and starter == '-':
    rest = tryopt[1:]
    tryopt = tryopt[0]
    if ignorecase > 1:
      tryopt = tryopt.lower()
    if debug:
      print '=> '+starter+tryopt+' unbundled from '+starter+tryopt+rest
    if rest == '':
      rest = None
    optbl = bopctl
    if bundling == 2 and opctl.has_key(tryopt+rest):
      opttype = opctl[tryopt+rest]
      if debug:
        print '=> '+starter+tryopt+' rebundled to '+starter+tryopt+rest
      tryopt += rest
      rest = None
  elif autoabbrev:
    if ignorecase: tryopt = opt = opt.lower()
    pat = re.escape(opt)
    hits = []
    p = re.compile('^'+pat)
    for o in names:
      if re.search(p,o): hits.append(o)
    if debug:
      print '=> %d hits with "%s" out of %d' % (len(hits),pat,len(names))
    nhits = 0
    for h in hits:
      if h == opt: nhits += 1
    if len(hits) > 1 and nhits != 1:
      hit = {}
      for h in hits:
        if aliases.has_key(h): h = aliases[h]
        hit[h] = 1
      if len(hit.keys()) != 1:
        if passthrough: return(0,None,None,None,None,None)
        print 'Warning: Option "'+opt+'" is ambiguous (%s)' % join(hits,', ')
        error += 1
        opt = None
        return(1,opt,arg,dsttype,incr,key)
      hits = hit.keys()
    if len(hits) == 1 and hits[0] != opt:
      tryopt = hits[0]
      if ignorecase: tryopt = tryopt.lower()
      if debug: print '=> option "'+opt+'" -> "'+tryopt+'"'
  elif ignorecase:
    tryopt = tryopt.lower()

  if opttype == None and optbl.has_key(tryopt):
    opttype = optbl[tryopt]
  if opttype == None:
    if passthrough: return(0,None,None,None,None,None)
    print 'Unknown option: '+opt
    error += 1
    return(1,opt,arg,dsttype,incr,key)
  opt = tryopt
  if debug: print '=> found "'+opttype+'" for '+opt

  if opttype == '' or opttype == '!' or opttype == '+':
    if optarg != None:
      if passthrough: return(0,None,None,None,None,None)
      print 'Warning: Option '+opt+' does not take an argument'
      error += 1
      opt = None
    elif opttype == '' or opttype == '+':
      arg = 1
      if opttype == '+': incr = 1
    else:
      opt = opt[2:]
      arg = 0
    if rest != None: sys.argv.insert(0,starter+rest)
    return(1,opt,arg,dsttype,incr,key)
    
  pm = re.search('^(.)(.)([@%]?)$',opttype)
  ( mand, opttype, dsttype ) = pm.groups()

  if (optarg != None and optarg == '') \
    or (optarg == None and not (rest != None or len(sys.argv) > 0)):
    if mand == '=':
      if passthrough: return(0,None,None,None,None,None)
      print 'Warning: Option '+opt+' requires an argument'
      error += 1
      opt = None
    if mand == ':':
      if opttype == 's': arg = ''
      else: arg = 0
    return(1,opt,arg,dsttype,incr,key)

  if rest != None: arg = rest
  elif optarg != None: arg = optarg
  else: arg = sys.argv.pop(0)

  key = None
  if dsttype == '%' and arg != None:
    pm = re.search('^(.*)=(.*)$',arg)
    if pm: key, arg = pm.groups()
    else: key, arg = ( arg, 1 )

# Needed to do the re pattern matching only
  if type(arg) == types.IntType: rarg = `arg`
  else: rarg = arg

  dsttype = opttype
  if opttype == 's':
    if mand == '=' or optarg != None or rest != None or arg == '-':
      return(1,opt,arg,dsttype,incr,key)
    if arg == argend or re.search('^'+prefix+'.+',arg):
      sys.argv.insert(0,arg)
      arg = ''
  elif opttype == 'n' or opttype == 'i':
    pm = None
    if rest != None:
      pm = re.search('^(-?[0-9]+)(.*)$',rest)
    if bundling and pm:
      arg = pm.group(1)
      rest = pm.group(2)
      if rest != None and rest != '': sys.argv.insert(0,starter+rest)
    elif not re.search('^-?[0-9]+$',rarg):
      if optarg != None or mand == '=':
        if passthrough:
          if optarg == None:
            if rest != None: sys.argv.insert(0,starter+rest)
            else: sys.argv.insert(0,arg)
          return(0,None,None,None,None,None)
        print 'Warning: Value "'+`arg`+'" invalid for option '+opt\
          +' (number expected)'
        error += 1
        opt = None
        if rest != None: sys.argv.insert(0,starter+rest)
      else:
        if rest != None: sys.argv.insert(0,starter+rest)
        else: sys.argv.insert(0,arg)
        arg = 0
  elif opttype == 'f':
    pm = None
    if rest != None:
      pm = re.search('^(-?[0-9]+(\.[0-9]+)?([eE]-?[0-9]+)?)(.*)$',rest)
    if bundling and pm:
        arg = pm.group(1)
# Should be last match bracket (not always 2nd group)
        rest = pm.group(2)
        if rest != None and rest != '': sys.argv.insert(0,starter+rest)
    elif not re.search('^-?[0-9.]+(\.[0-9]+)?([eE]-?[0-9]+)?$',rarg):
      if optarg != None or mand == '=':
        if passthrough:
          if optarg == None:
            if rest != None: sys.argv.insert(0,starter+rest)
            else: sys.argv.insert(0,arg)
          return(0,None,None,None,None,None)
        print 'Warning: Value "'+`arg`+'" invalid for option '+opt\
          +' (real number expected)'
        error += 1
        opt = None
        if rest != None: sys.argv.insert(0,starter+rest)
      else:
        if rest != None: sys.argv.insert(0,starter+rest)
        else: sys.argv.insert(0,arg)
        arg = 0.0
  else:
# Perl croaks/aborts here - internal error can't happen
    pass
  return(1,opt,arg,dsttype,incr,key)

# Values for $order. See GNU getmyOptions.c for details.
REQUIRE_ORDER, PERMUTE, RETURN_IN_ORDER = 0, 1, 2

( major_version, minor_version ) = re.search('^(\d+)\.(\d+)',VERSION).groups()

ConfigDefaults()

################ Documentation ################
"""

=head1 NAME

Options - extended processing of command line options

=head1 SYNOPSIS

  import Options
  from Options import OptionClass, Configure, GetOptions, myOptions

  Configure(...configuration-parameters...)
  result = GetOptions(...option-descriptions...)

=head1 DESCRIPTION

The Options module implements an extended getopt function called
GetOptions(). This function adheres to the POSIX syntax for command
line options, with GNU extensions. In general, this means that options
have long names instead of single letters, and are introduced with a
double dash "--". Support for bundling of command line options, as was
the case with the more traditional single-letter approach, is provided
but not enabled by default. For example, the UNIX "ps" command can be
given the command line "option"

  -vax

which means the combination of B<-v>, B<-a> and B<-x>. With the new
syntax B<--vax> would be a single option, probably indicating a
computer architecture. 

Command line options can be used to set values. These values can be
specified in one of two ways:

  --size 24
  --size=24

GetOptions is called with a list of option-descriptions. Each is either
just a string with the option specifier or a tuple consisting of a
string with the option specifier and the option linkage. The option
specifier defines the name of the option and, optionally, the value it
can take. The option linkage is a string with a reference name or a
reference to a list, dictionary or function that will be set/called
when the option is used. For example, the following call to GetOptions:

  GetOptions(('size=i','offset'));

will accept a command line option "size" that must have an integer
value. With a command line of "--size 24" this will cause the offset
member of the myOptions class instance to get the value 24. You can
use an alternative class instance to myOptions by passing the name
in the Configure call (see later section).

Alternatively, the first argument to GetOptions may be a reference to
a dictionary describing the linkage for the options. The following call
is equivalent to the example above:

  optctl = { 'size' : 'offset' }
  GetOptions(optctl, 'size=i');

Linkage may be specified using either of the above methods, or both.
Linkage specified in the argument list takes precedence over the
linkage specified in the dictionary.

The command line options are taken from the sys.argv list. Upon completion
of GetOptions, sys.argv will contain the rest (i.e. the non-options) of
the command line.
 
Each option specifier designates the name of the option, optionally
followed by an argument specifier.

Options that do not take arguments will have no argument specifier. 
The option variable will be set to 1 if the option is used.

For the other options, the values for argument specifiers are:

=over 8

=item !

Option does not take an argument and may be negated, i.e. prefixed by
"no". E.g. "foo!" will allow B<--foo> (with value 1) and B<-nofoo>
(with value 0). The option variable will be set to 1, or 0 if negated.

=item +

Option does not take an argument and will be incremented by 1 every
time it appears on the command line. E.g. "more+", when used with
B<--more --more --more>, will set the option variable to 3 (provided
it was 0 or undefined at first).

The B<+> specifier is ignored if the option destination is not a SCALAR.

=item =s

Option takes a mandatory string argument.
This string will be assigned to the option variable.
Note that even if the string argument starts with B<-> or B<-->, it
will not be considered an option on itself.

=item :s

Option takes an optional string argument.
This string will be assigned to the option variable.
If omitted, it will be assigned "" (an empty string).
If the string argument starts with B<-> or B<-->, it
will be considered an option on itself.

=item =i

Option takes a mandatory integer argument.
This value will be assigned to the option variable.
Note that the value may start with B<-> to indicate a negative
value. 

=item :i

Option takes an optional integer argument.
This value will be assigned to the option variable.
If omitted, the value 0 will be assigned.
Note that the value may start with B<-> to indicate a negative
value.

=item =f

Option takes a mandatory real number argument.
This value will be assigned to the option variable.
Note that the value may start with B<-> to indicate a negative
value.

=item :f

Option takes an optional real number argument.
This value will be assigned to the option variable.
If omitted, the value 0 will be assigned.

=back

A lone dash B<-> is considered an option, the corresponding option
name is the empty string.

A double dash on itself B<--> signals end of the options list.

=head2 Linkage specification

The linkage specifier is optional. If no linkage is explicitly
specified but a dictionary is passed, GetOptions will place the value in
the dictionary. For example:

  optctl = {}
  GetOptions(optctl,'size=i')

with command line "--size 24" will perform the equivalent of
the assignment

  optctl['size'] = 24

For list options, a reference to a list is used, e.g.:

  optctl = {};
  GetOptions(optctl,'sizes=i@')

with command line "-sizes 24 -sizes 48" will perform the equivalent of
the assignment

  optctl['sizes'] = [24, 48]

For dictionary options (an option whose argument looks like "name=value"),
a reference to a dictionary is used, e.g.:

  optctl = {};
  GetOptions(optctl,'define=s%')

with command line "--define foo=hello --define bar=world" will perform the
equivalent of the assignment

  optctl['define'] = { foo : 'hello', bar : 'world' }

If no linkage is explicitly specified and no dictionary is passed,
GetOptions will put the value in a class member named after the
option, prefixed by "myOptions.". To yield a usable name,
characters that are not part of the syntax for variables are
translated to underscores. For example, "--fpp-struct-return" will set
the variable myOptions.fpp_struct_return. For example:

  GetOptions('size=i','sizes=i@')

with command line "-size 10 -sizes 24 -sizes 48" will perform the
equivalent of the assignments

  myOptions.size = 10
  myOptions.sizes = [ 24, 48 ]

A lone dash B<-> is considered an option, the corresponding
identifier is myOptions.??? .

The linkage specifier can be a string (reference to a variable name),
a reference to a list, a reference to a dictionary or a reference
to a function.

If a STRING is supplied, the new value is stored in the referenced
variable. If the option occurs more than once, the previous value is
overwritten. For example with command line "--size=24":

  myOptions.mysize = 4
  GetOptions(('size=i','mysize'))
  myOptions.mysize == 24

If a LIST is supplied, the new value is appended (pushed) to the
referenced list.  For example with command line "--size=24":

  myOptions.mysizes = [ 4 ]
  GetOptions(('size=i',mysizes))
  myOptions.mysizes == [ 4, 24 ]

If a DICTIONARY is supplied, the option value should look like "key" or
"key=value" (if the "=value" is omitted then a value of 1 is implied).
In this case, the element of the referenced dictionary with the key "key"
is assigned "value". For example with command line "--define TEST=YES":

  myOptions.mydefines = {}
  GetOptions(('define=s',mydefines))
  myOptions.mydefines['TEST'] == 'YES'

If a FUNCTION is supplied, the referenced subroutine is called with
two arguments: the option name and the option value.
The option name is always the true name, not an abbreviation or alias.
For example with command line "--size=24":

  def myarg(opt,arg):
    x = opt
    y = arg

  GetOptions(('size=i',myarg))
  x == 'size'
  y == 24

=head2 Aliases and abbreviations

The option name may actually be a list of option names, separated by
"|"s, e.g. "foo|bar|blech=s". In this example, "foo" is the true name
of this option. If no linkage is specified, options "foo", "bar" and
"blech" all will set myOptions.foo. For convenience, the single character
"?" is allowed as an alias, e.g. "help|?".

Option names may be abbreviated to uniqueness, depending on
configuration option B<auto_abbrev>.

=head2 Non-option call-back routine

A special option specifier, E<lt>E<gt>, can be used to designate a function
to handle non-option arguments. GetOptions will immediately call this
function for every non-option it encounters in the options list.
This function gets the name of the non-option passed.
This feature requires configuration option B<permute>, see section
CONFIGURATION OPTIONS.

See also the examples.

=head2 Option starters

On the command line, options can start with B<-> (traditional), B<-->
(POSIX) and B<+> (GNU, now being phased out). The latter is not
allowed if the environment variable B<POSIXLY_CORRECT> has been
defined.

Options that start with "--" may have an argument appended, separated
with an "=", e.g. "--foo=bar".

=head2 Return values and Errors

Configuration errors and errors in the option definitions return to
the calling program. Messages are printed.

A return value of 1 (true) indicates success.

A return status of 0 (false) indicates that the function detected one
or more errors during option parsing.

=head1 COMPATIBILITY

If an "@" sign is appended to the argument specifier, the option is
treated as a list. Value(s) are not set, but pushed into list
myOptions.name. If explicit linkage is supplied, this must be a reference
to a list.

If an "%" sign is appended to the argument specifier, the option is
treated as a dictionary. Value(s) of the form "name=value" are set by
setting the element of the dictionary myOptions.name with key "name" to "value"
(if the "=value" portion is omitted it defaults to 1). If explicit
linkage is supplied, this must be a reference to a dictionary.

If configuration option B<getopt_compat> is set (see section
CONFIGURATION OPTIONS), options that start with "+" or "-" may also
include their arguments, e.g. "+foo=bar". This is for compatiblity
with older implementations of the GNU "getopt" routine.

For convenience, option specifiers may have a leading B<-> or B<-->,
so it is possible to write:

   Options.GetOptions('-foo=s','--bar=i','--ar=s')

=head1 EXAMPLES

If the option specifier is "one:i" (i.e. takes an optional integer
argument), then the following situations are handled:

   -one -two		-> myOptions.one = '', -two is next option
   -one -2		-> myOptions.one = -2

Also, assume specifiers "foo=s" and "bar:s" :

   -bar -xxx		-> myOptions.bar = '', '-xxx' is next option
   -foo -bar		-> myOptions.foo = '-bar'
   -foo --		-> myOptions.foo = '--'

In GNU or POSIX format, option names and values can be combined:

   +foo=blech		-> myOptions.foo = 'blech'
   --bar=		-> myOptions.bar = ''
   --bar=--		-> myOptions.bar = '--'

Example of using variable references:

   ret = Options.GetOptions(('foo=s','foo'),'bar=i',('ar=s',ar))

With command line options "-foo blech -bar 24 -ar xx -ar yy" 
this will result in:

   foo = 'blech'
   myOptions.bar = 24
   ar = [ 'xx', 'yy' ]

Example of using the E<lt>E<gt> option specifier:

   sys.argv = [ '-foo', 1, 'bar', '-foo', 2, 'blech' ]
   Options.GetOptions(('foo=i','myfoo'),('<>',mysub))

Results:

   mysub('bar') will be called (with myfoo being 1)
   mysub('blech') will be called (with myfoo being 2)

Compare this with:

   sys.argv = [ '-foo', 1, 'bar', '-foo', 2, 'blech' ]
   Options.GetOptions(('foo=i','myfoo'))

This will leave the non-options in sys.argv:

   myfoo -> 2
   sys.argv -> [ 'bar', 'blech' ]

=head1 CONFIGURATION OPTIONS

B<GetOptions> can be configured by calling subroutine
B<Configure>. This subroutine takes a list of quoted
strings, each specifying a configuration option to be set, e.g.
B<ignore_case>. Options can be reset by prefixing with B<no_>, e.g.
B<no_ignore_case>. Case does not matter. Multiple calls to B<Configure>
are possible.

Any configuration option can be given as a class instance instead. In
this case that class will be used for the creation of option member
variables rather than the default (which is Options.OptionClass). If
so desired it can be subclassed. Initial arguments create those members
with default values for options. For example:

  sys.argv -> [ '--Test=5' ]

  opt = OptionClass(test=0)
  Configure(opt,'ignorecase')
  GetOptions('test=i')

  opt.test -> 5

Without the above the default assignment is:

  myOptions.test -> 5

The following configuration parameters are available:

=over 12

=item default

This option causes all configuration options to be reset to their
default values.

=item auto_abbrev

Allow option names to be abbreviated to uniqueness.
Default is set unless environment variable
POSIXLY_CORRECT has been set, in which case B<auto_abbrev> is reset.

=item getopt_compat   

Allow '+' to start options.
Default is set unless environment variable
POSIXLY_CORRECT has been set, in which case B<getopt_compat> is reset.

=item require_order

Whether non-options are allowed to be mixed with
options.
Default is set unless environment variable
POSIXLY_CORRECT has been set, in which case b<require_order> is reset.

See also B<permute>, which is the opposite of B<require_order>.

=item permute

Whether non-options are allowed to be mixed with
options.
Default is set unless environment variable
POSIXLY_CORRECT has been set, in which case B<permute> is reset.
Note that B<permute> is the opposite of B<require_order>.

If B<permute> is set, this means that 

    -foo arg1 -bar arg2 arg3

is equivalent to

    -foo -bar arg1 arg2 arg3

If a non-option call-back routine is specified, sys.argv will always be
empty upon succesful return of GetOptions since all options have been
processed, except when B<--> is used:

    -foo arg1 -bar arg2 -- arg3

will call the call-back routine for arg1 and arg2, and terminate
leaving arg2 in sys.argv.

If B<require_order> is set, options processing
terminates when the first non-option is encountered.

    -foo arg1 -bar arg2 arg3

is equivalent to

    -foo -- arg1 -bar arg2 arg3

=item bundling (default: reset)

Setting this variable to a non-zero value will allow single-character
options to be bundled. To distinguish bundles from long option names,
long options must be introduced with B<--> and single-character
options (and bundles) with B<->. For example,

    ps -vax --vax

would be equivalent to

    ps -v -a -x --vax

provided "vax", "v", "a" and "x" have been defined to be valid
options. 

Bundled options can also include a value in the bundle; for strings
this value is the rest of the bundle, but integer and floating values
may be combined in the bundle, e.g.

    scale -h24w80

is equivalent to

    scale -h 24 -w 80

Note: resetting B<bundling> also resets B<bundling_override>.

=item bundling_override (default: reset)

If B<bundling_override> is set, bundling is enabled as with
B<bundling> but now long option names override option bundles. In the
above example, B<-vax> would be interpreted as the option "vax", not
the bundle "v", "a", "x".

Note: resetting B<bundling_override> also resets B<bundling>.

B<Note:> Using option bundling can easily lead to unexpected results,
especially when mixing long options and bundles. Caveat emptor.

=item ignore_case  (default: set)

If set, case is ignored when matching options.

Note: resetting B<ignore_case> also resets B<ignore_case_always>.

=item ignore_case_always (default: reset)

When bundling is in effect, case is ignored on single-character
options also. 

Note: resetting B<ignore_case_always> also resets B<ignore_case>.

=item pass_through (default: reset)

Unknown options are passed through in sys.argv instead of being flagged
as errors. This makes it possible to write wrapper scripts that
process only part of the user supplied options, and passes the
remaining options to some other program.

This can be very confusing, especially when B<permute> is also set.

=item prefix

The string that starts options. See also B<prefix_pattern>.

=item prefix_pattern

A regular expression that identifies the strings that introduce options.
Default is C<(--|-|\+)> unless environment variable
POSIXLY_CORRECT has been set, in which case it is C<(--|-)>.

=item debug (default: reset)

Enable copious debugging output.

=back

=head1 AUTHOR

Johan Vromans E<lt>jvromans@squirrel.nlE<gt>
Port from Perl to Python by Tim Colles E<lt>timc@dai.ed.ac.ukE<gt>

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 1990,1998 by Johan Vromans.
This port is Copyright 2001 by Tim Colles.
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

If you do not have a copy of the GNU General Public License write to
the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, 
MA 02139, USA.

=cut

"""
