# Always use highest version of Raku until 6.e is default
use v6.*;

#- HELPER SUBS -----------------------------------------------------------------
# What to return if a localization is not known
my sub unknown(Str:D $localization) is hidden-from-backtrace {
    "Unknown localization '$localization'".Failure
}

# Simple mapping 1 to N mapping logic as a Map
my sub mapify(%hash) {
    my %mapper;
    %mapper{.value}.push(.key) for %hash;
    $_ := .sort.List for %mapper.values;
    %mapper.Map
}

# Produce all words on non-commented lines of given IO as a Slip
my sub io2words(IO::Path:D $io) {
    $io.lines.map: { .words.Slip unless .starts-with("#") }
}

# Create default name of executor from a language
my sub language2executor(Str:D $language --> Str:D) {
    "$language.lc.substr(0,3)ku"
}

#- AST BUILDING LOGIC ----------------------------------------------------------
# These subs create ASTs, or help in creating them

#- make-mapper2ast -------------------------------------------------------------
# Return the AST for translation lookup logic, basically:
#
# method $name {
#     my constant %mapping = @operands;
#     my $ast  := self.ast;
#     my $name := $ast ?? $ast.simple-identifier !! self.Str;
#     if %mapping{$name} -> $original {
#         RakuAST::Name.from-identifier($original)
#     }
#     else {
#         $ast // RakuAST::Name.from-identifier($name)
#     }
# }
#
# if there are any operands, otherwise:
#
# method $name { self.ast // RakuAST::Name.from-identifier(self.Str) }
#
my sub make-mapper2ast(str $name, @operands) {
    my $stmts := @operands
      ?? RakuAST::StatementList.new(
           RakuAST::Statement::Expression.new(
             expression => RakuAST::VarDeclaration::Constant.new(
               scope       => "my",
               name        => "\%mapping",
               initializer => RakuAST::Initializer::Assign.new(
                 RakuAST::ApplyListInfix.new(
                   infix    => RakuAST::Infix.new(","),
                   operands => @operands,
                 )
               )
             )
            ),
            RakuAST::Statement::Expression.new(
              expression => RakuAST::VarDeclaration::Simple.new(
                sigil       => "\$",
                desigilname => RakuAST::Name.from-identifier("ast"),
                initializer => RakuAST::Initializer::Bind.new(
                  RakuAST::ApplyPostfix.new(
                    operand => RakuAST::Term::Self.new,
                    postfix => RakuAST::Call::Method.new(
                      name => RakuAST::Name.from-identifier("ast")
                    )
                  )
                )
              )
            ),
            RakuAST::Statement::Expression.new(
              expression => RakuAST::VarDeclaration::Simple.new(
                sigil       => "\$",
                desigilname => RakuAST::Name.from-identifier("name"),
                initializer => RakuAST::Initializer::Bind.new(
                  RakuAST::Ternary.new(
                    condition => RakuAST::Var::Lexical.new("\$ast"),
                    then      => RakuAST::ApplyPostfix.new(
                      operand => RakuAST::Var::Lexical.new("\$ast"),
                      postfix => RakuAST::Call::Method.new(
                        name => RakuAST::Name.from-identifier("simple-identifier")
                      )
                    ),
                    else      => RakuAST::ApplyPostfix.new(
                      operand => RakuAST::Term::Self.new,
                      postfix => RakuAST::Call::Method.new(
                        name => RakuAST::Name.from-identifier("Str")
                      )
                    )
                  )
                )
              )
            ),
            RakuAST::Statement::If.new(
              condition => RakuAST::ApplyPostfix.new(
                operand => RakuAST::Var::Lexical.new("\%mapping"),
                postfix => RakuAST::Postcircumfix::HashIndex.new(
                  index => RakuAST::SemiList.new(
                    RakuAST::Statement::Expression.new(
                      expression => RakuAST::Var::Lexical.new("\$name")
                    )
                  )
                )
              ),
              then      => RakuAST::PointyBlock.new(
                signature => RakuAST::Signature.new(
                  parameters => (
                    RakuAST::Parameter.new(
                      target => RakuAST::ParameterTarget::Var.new(
                        :name<$original>
                      )
                    ),
                  )
                ),
                body      => RakuAST::Blockoid.new(
                  RakuAST::StatementList.new(
                    RakuAST::Statement::Expression.new(
                      expression => RakuAST::ApplyPostfix.new(
                        operand => RakuAST::Type::Simple.new(
                          RakuAST::Name.from-identifier-parts("RakuAST","Name")
                        ),
                        postfix => RakuAST::Call::Method.new(
                          name => RakuAST::Name.from-identifier("from-identifier"),
                          args => RakuAST::ArgList.new(
                            RakuAST::Var::Lexical.new("\$original")
                          )
                        )
                      )
                    )
                  )
                )
              ),
              else      => RakuAST::Block.new(
                body => RakuAST::Blockoid.new(
                  RakuAST::StatementList.new(
                    RakuAST::Statement::Expression.new(
                      expression => RakuAST::ApplyInfix.new(
                        left  => RakuAST::Var::Lexical.new("\$ast"),
                        infix => RakuAST::Infix.new("//"),
                        right => RakuAST::ApplyPostfix.new(
                          operand => RakuAST::Type::Simple.new(
                            RakuAST::Name.from-identifier-parts("RakuAST","Name")
                          ),
                          postfix => RakuAST::Call::Method.new(
                            name => RakuAST::Name.from-identifier("from-identifier"),
                            args => RakuAST::ArgList.new(
                              RakuAST::Var::Lexical.new("\$name")
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
      !! RakuAST::StatementList.new(
           RakuAST::Statement::Expression.new(
             expression => RakuAST::ApplyInfix.new(
               left  => RakuAST::ApplyPostfix.new(
                 operand => RakuAST::Term::Self.new,
                 postfix => RakuAST::Call::Method.new(
                   name => RakuAST::Name.from-identifier("ast")
                 )
               ),
               infix => RakuAST::Infix.new("//"),
               right => RakuAST::ApplyPostfix.new(
                 operand => RakuAST::Type::Simple.new(
                   RakuAST::Name.from-identifier-parts("RakuAST","Name")
                 ),
                 postfix => RakuAST::Call::Method.new(
                   name => RakuAST::Name.from-identifier("from-identifier"),
                   args => RakuAST::ArgList.new(
                     RakuAST::ApplyPostfix.new(
                       operand => RakuAST::Term::Self.new,
                       postfix => RakuAST::Call::Method.new(
                         name => RakuAST::Name.from-identifier("Str")
                       )
                     )
                   )
                 )
               )
             )
           )
         );

    # wrap the statements into a method
    RakuAST::Statement::Expression.new(
      expression => RakuAST::Method.new(
        name  => RakuAST::Name.from-identifier($name),
        body  => RakuAST::Blockoid.new($stmts)
      )
    )
}

#- make-mapper2str -------------------------------------------------------------
# Return the str translation lookup logic, basically:
#
# method $name(str $key) {
#     my constant %mapping = @operands;
#     %mapping{$key} // $key
# }
#
# if there are any operands, otherwise:
#
# method $name(str $key) { $key }
#
my sub make-mapper2str(str $name, @operands) {
    my $stmts := @operands
      ?? RakuAST::StatementList.new(
           RakuAST::Statement::Expression.new(
             expression => RakuAST::VarDeclaration::Constant.new(
               scope       => "my",
               name        => "\%mapping",
               initializer => RakuAST::Initializer::Assign.new(
                 RakuAST::ApplyListInfix.new(
                   infix    => RakuAST::Infix.new(","),
                   operands => @operands,
                 )
               )
             )
           ),
           RakuAST::Statement::Expression.new(
             expression => RakuAST::ApplyInfix.new(
               left  => RakuAST::ApplyPostfix.new(
                 operand => RakuAST::Var::Lexical.new("\%mapping"),
                 postfix => RakuAST::Postcircumfix::HashIndex.new(
                   index => RakuAST::SemiList.new(
                     RakuAST::Statement::Expression.new(
                       expression => RakuAST::Var::Lexical.new("\$key")
                     )
                   )
                 )
               ),
               infix => RakuAST::Infix.new("//"),
               right => RakuAST::Var::Lexical.new("\$key")
             )
           )
         )
      !! RakuAST::StatementList.new(
           RakuAST::Statement::Expression.new(
             expression => RakuAST::Var::Lexical.new("\$key")
           )
         );

    # Wrap the statements into a method
    RakuAST::Method.new(
      name      => RakuAST::Name.from-identifier($name),
      signature => RakuAST::Signature.new(
        parameters => (
          RakuAST::Parameter.new(
            type   => RakuAST::Type::Simple.new(
              RakuAST::Name.from-identifier("str")
            ),
            target => RakuAST::ParameterTarget::Var.new(
              :name<$key>
            )
          ),
        )
      ),
      body      => RakuAST::Blockoid.new($stmts)
    )
}

# Append a given key and value to the given array if the value is different
# from the key
my sub accept(str $key, str $value, @array) {
    @array.append(
      RakuAST::StrLiteral.new($key),
      RakuAST::StrLiteral.new($value)
    ) if $value ne $key;
}

#- CONSTANTS -------------------------------------------------------------------
# Please keep constant definitions on alphabetical order, thank you!
my constant %binary2localization = <
  churras PT
  denata  PT
  deuku   DE
  draig   CY
  fraku   FR
  hunku   HU
  itaku   IT
  japku   JA
  kaas    NL
  nedku   NL
  porku   PT
  ryuu    JA
  strudel DE
>;

my constant %extension2localization = <
  brie    FR
  churras PT
  denata  PT
  deuku   DE
  draig   CY
  fraku   FR
  hunku   HU
  itaku   IT
  japku   JA
  kaas    NL
  nedku   NL
  porku   PT
  ryuu    JA
  strudel DE
>;

my constant %localization2language = <
  CY  Welsh
  DE  German
  EN  English
  FR  French
  HU  Hungarian
  JA  Japanese
  NL  Dutch
  PT  Portuguese
>;

my constant $extension     = 'l10n';
my constant @extensions    = %extension2localization.keys.sort;
my constant @localizations = %localization2language.keys.sort;
my constant @binaries      = %binary2localization.keys.sort;

my constant %extensions-for-localization = mapify %extension2localization;
my constant %binaries-for-localization   = mapify %binary2localization;

# Known groups of translation
my constant %known-groups = <
  adverb-pc adverb-q adverb-rx block constraint core enum infix meta
  modifier multi named package phaser pragma prefix quote-lang routine
  scope stmt-prefix system term traitmod trait-is typer use
>.map({ $_ => 1 });
my constant %sub-groups = <core named>.map({ $_ => 1 });

#- L10N ------------------------------------------------------------------------
# The class on which only class methods can be called.  Why not export as
# subroutines you say?  Simply, to prevent unneeded poisonin of namespaces

unit class L10N is repr('Uninstantiable');

#- RUNTIME METHODS -------------------------------------------------------------
method role-for-localization(Str:D $localization) {
    try "use L10N::$localization 'no-slangification'".EVAL
      unless L10N::.EXISTS-KEY($localization);

    L10N::.EXISTS-KEY($localization) ?? L10N::{$localization} !! True
}

method localization-for-path(IO(Str:D) $io) {
    %extension2localization{$io.extension} // Nil
}

#- SETUP METHODS ---------------------------------------------------------------
method fresh-distribution(
  IO()      $dir,
  Str:D     $language,
  Str:D    :$auth         = "zef:l10n",
  Str:D    :$author       = $*USER.tclc,
  Str:D    :$copyright    = "Raku Localization Team",
  Str:D    :$email        = "l10n@raku.org",
  Str:D    :$executor     = language2executor($language),
  Str:D    :$localization = $dir.basename,
  Str(Int) :$year         = DateTime.now.year,
) {
    die "Can only create a fresh distribution in a new directory"
      if $dir.d && $dir.dir.elems;

    # Slurp a file from resources, and do the necessary substitutions
    my sub slurp(Str:D $key) {
        with %?RESOURCES{$key} -> $handle {
            $handle.open.slurp(:close)
              .subst("#AUTHOR#",       $author,       :g)
              .subst("#LANGUAGE#",     $language,     :g)
              .subst("#LOCALIZATION#", $localization, :g)
              .subst("#AUTH#",         $auth,         :g)
              .subst("#EMAIL#",        $email,        :g)
              .subst("#COPYRIGHT#",    $copyright,    :g)
              .subst("#EXECUTOR#",     $executor,     :g)
              .subst("#YEAR#",         $year,         :g)
        }
        else {
            die "'$key' does not appear to be a resource";
        }
    }

    # Create a file from the resources
    my sub spurt(Str:D $key, $io = $dir) {
        $io.add($key).spurt(slurp $key)
    }

    # Run a script in the given directory
    my sub run-script($script, *@args) {
        indir $dir, {
            my $proc := run $script, @args;
            $proc.exitcode
              ?? die $!
              !! True
        }
    }

    # Make sure there *is* a directory to write files to
    $dir.mkdir;

    # Files with same name in root directory
    spurt($_) for <Changes dist.ini .gitignore LICENSE META6.json run-tests>;

    # Add test file
    my $t := $dir.add("t");
    $t.mkdir;
    spurt('01-basic.rakutest', $t);

    # Add CI runners
    my $workflows := $dir.add(<.github workflows>);
    $workflows.mkdir;
    spurt("$_.yml", $workflows) for <linux macos windows>;

    # Add the documentation file
    my $doc := $dir.add("doc");
    $doc.mkdir;
    $doc.add("L10N-$localization.rakudoc").spurt(slurp "L10N.rakudoc");

    # Add a translation file to work with
    self.fresh-translation-file($localization, $language, $dir);

    # Add a fresh executor file
    self.fresh-executor-file($localization, $language, $executor, $dir);

    # Make sure we have source files
    self.update-localization-modules($dir.add("$localization.$extension"));

    # Prepare for use with git
    run-script "git", "init";
    run-script "git", <add .>;
    run-script "git", <<commit -a "-mInitial commit from L10N.fresh-distribution">>;

    # Make sure we have a README.md
    run-script "mi6", "build"
}

method fresh-translation(Str:D $name) {
    my str @lines = %?RESOURCES<NULL-TRANSLATION>.open.lines(:close).map: {
        if .starts-with("#") {
            $_ if .starts-with("# KEY" | "# vim")
        }
        else {
            $_ ?? "#$_" !! ""
        }
    }

    qq:to/HEADER/ ~ @lines.join("\n")
# This file contains the $name localization of the
# Raku Programming Language.
#
# CONTRIBUTORS:
#
# See https://github.com/Raku-L10N/L10N/ for more information
HEADER
}

method fresh-translation-file(
  Str:D   $id,
  Str:D   $name = $id,
  IO(Str) $dir  = "."
) {
    $dir.add("$id.$extension").spurt(self.fresh-translation($name))
}

method fresh-executor(Str:D $id, Str:D $language) {
    qq:to/CODE/
#!/usr/bin/env raku

# Executor for the $language localization of the Raku Programming Language

\%*ENV<RAKUDO_RAKUAST> = 1;
\%*ENV<RAKUDO_OPT>     = '-ML10N::$id';

my \$proc := run \$*EXECUTABLE, @*ARGS;
exit \$proc.exitcode;

# vim: expandtab shiftwidth=4
CODE
}

method fresh-executor-file(
  Str:D   $id,
  Str:D   $language,
  Str:D   $name = language2executor($language),
  IO(Str) $dir  = "."
) {
    my $bin := $dir.add("bin");
    $bin.mkdir;
    $bin.add($name).spurt(self.fresh-executor($id, $language))
}

#- UPDATE METHODS --------------------------------------------------------------

my @core-translations;
# Return the list of core translations
method !core() {
    @core-translations
      ?? @core-translations
      !! @core-translations =
           %?RESOURCES<NULL-TRANSLATION>.open.lines(:close).map: {
               .words.Slip unless .starts-with("#")
           }
}

#- read-hash -------------------------------------------------------------------
proto method read-hash(|) {*}

# Produce the "bare" core translations
multi method read-hash() { %(flat self!core) }

# Read translation hash from given file
multi method read-hash(IO(Str) $io, :$core) {
    $core
      ?? %(flat self!core, io2words($io))
      !! %(io2words($io))
}

#- missing-translations --------------------------------------------------------
# Return a sorted list of keys that do not have a translation for a given IO
method missing-translations(IO(Str) $io) {
    (self.read-hash (-) self.read-hash($io)).keys.sort
}

#- write-hash ------------------------------------------------------------------
# Write out the localization of the given hash to the given file (as IO object)
method write-hash(IO::Path:D $io, %mapping) {

    # Return the group for the given key
    my %groups;
    my sub group-hash(Str:D $key) {
        my int $disabled = +$key.starts-with("#");
        my str @parts    = $key.split("-");

        # The group is determined from the given key, taking into account
        # a potential "#" prefix on the key.  Since some keys contain hyphens
        # and the rest of the key can also contain hyphens, we need to do
        # this dance to find a legal key to be used.
        my str $group = @parts.shift;
        $group = $group.substr(1) if $disabled;
        until %known-groups{$group} || !@parts {
            $group = $group ~ "-" ~ @parts.shift;
        }
        die "No group found for $key" unless @parts;

        # Groups with many potential localization keys, are divided into
        # sub-groups including the first letter.
        $group ~= $key.substr($group.chars + $disabled, 2).lc
          if %sub-groups{$group};

        # Fetch or create the hash
        %groups{$group} // (%groups{$group} := {})
    }

    # Set up base information, including translations not yet done (which
    # start with an "#" immediately followed by the key.)
    for $io.lines {
        unless .starts-with("# ") || $_ eq "#" || .is-whitespace {
            my ($key,$translation) = .words;
            group-hash($key){$key} := $translation;
        }
    }

    # Update the groups from the given hash
    for %mapping {
        my $key  := .key;
        my %hash := group-hash($key);
        %hash{"#$key"}:delete;  # remove any untranslated
        %hash{$key} := .value;  # set as translated
    }

    # Start building the file
    my str @lines;
    my $handle := $io.open(:!chomp);
    for $handle.lines {
        .starts-with("#")
          ?? @lines.push($_)
          !! last
    }
    $handle.close;

    # Add the lines with the translations in correct order to reduce the
    # amount of changes on updates.
    for %groups.sort(*.key) {
        my %hash   := %groups{.key};
        my int $max = %hash.keys.map({ .chars - .starts-with("#") }).max;
        my $format := '%-' ~ $max ~ "s  %s\n";

        @lines.push("\n");
        @lines.push(sprintf($format, "# KEY", "TRANSLATION"));

        for %hash.sort(-> $a is copy, $b is copy {
            $a = $a.key;
            $a = $a.substr(1) if $a.starts-with("#");
            $b = $b.key;
            $b = $b.substr(1) if $b.starts-with("#");

            $a.fc cmp $b.fc || $b cmp $a
        }) {
            my $key := .key;
            @lines.push($key.starts-with("#")
              ?? "#" ~ sprintf($format, $key.substr(1), .value)
              !! sprintf($format, $key, .value)
            );
        }
    }

    # Put in the vim marker
    @lines.push("\n");
    @lines.push("# vim: expandtab shiftwidth=4\n");

    $io.spurt(@lines.join);
}

#- slangify --------------------------------------------------------------------
# Return the RakuAST of a role with the given name from the given translation
# hash to be used to create a slang.
method slangify($localization, %hash) is export {
    my $statements := RakuAST::StatementList.new;

    # Needs 'use experimental :rakuast' in case source is generated
    $statements.add-statement: RakuAST::Statement::Use.new(
      module-name => RakuAST::Name.from-identifier("experimental"),
      argument    => RakuAST::ColonPair::True.new("rakuast")
    );

    # Run over the given hash, sorted by key
    my @adverb-pc;
    my @adverb-q;
    my @adverb-rx;
    my @core;
    my @named;
    my @enum;
    my @pragma;
    my @quote-lang;
    my @system;
    my @trait-is;
    for %hash.sort(-> $a, $b {
        $a.key.fc cmp $b.key.fc || $b.key cmp $a.key
    }) -> (:key($name), :value($string)) {

        # It's a sub / method name
        if $name.starts-with('core-') {
            accept($string, $name.substr(5), @core);
        }

        # It's a named argument
        elsif $name.starts-with('named-') {
            accept($string, $name.substr(6), @named);
        }

        # It's an "is" trait
        elsif $name.starts-with('trait-is-') {
            accept($string, $name.substr(9), @trait-is);
        }

        # It's a postfix adverb
        elsif $name.starts-with('adverb-pc-') {
            accept($string, $name.substr(10), @adverb-pc);
        }

        # It's a quote adverb
        elsif $name.starts-with('adverb-q-') {
            accept($string, $name.substr(9), @adverb-q);
        }

        # It's a regex adverb
        elsif $name.starts-with('adverb-rx-') {
            accept($string, $name.substr(10), @adverb-rx);
        }

        # It's a pragma
        elsif $name.starts-with('pragma-') {
            accept($string, $name.substr(7), @pragma);
        }

        # It's a system method
        elsif $name.starts-with('system-') {
            accept($string, $name.substr(7), @system);
        }

        # Some other core feature, add a token for it
        else {
            $statements.add-statement: RakuAST::Statement::Expression.new(
              expression => RakuAST::TokenDeclaration.new(
                name => RakuAST::Name.from-identifier(
                  $name.trans('^()' => 'cpp')  # handle bad chars
                ),
                body => RakuAST::Regex::Sequence.new(
                  RakuAST::Regex::Literal.new($string)
                )
              )
            );
        }
    }

    # Add methods for mappers
    $statements.add-statement: make-mapper2ast('core2ast',      @core     );
    $statements.add-statement: make-mapper2ast('trait-is2ast',  @trait-is );
    $statements.add-statement: make-mapper2str('adverb-pc2str', @adverb-pc);
    $statements.add-statement: make-mapper2str('adverb-q2str',  @adverb-q );
    $statements.add-statement: make-mapper2str('adverb-rx2str', @adverb-rx);
    $statements.add-statement: make-mapper2str('named2str',     @named    );
    $statements.add-statement: make-mapper2str('pragma2str',    @pragma   );
    $statements.add-statement: make-mapper2str('system2str',    @system   );

    # Wrap the whole thing up in a role with the given name and return it
    RakuAST::Role.new(
      name => RakuAST::Name.from-identifier-parts('L10N',$localization),
      body => RakuAST::RoleBody.new(
        body => RakuAST::Blockoid.new($statements)
      )
    )
}

#- deparsify -------------------------------------------------------------------
# Return the RakuAST of a role with the given name from the given translation
# hash to be used to create a slang.
method deparsify($language, %hash) {
    my $statements := RakuAST::StatementList.new;

    # Run over the given hash, sorted by key
    my @operands = %hash.sort(-> $a, $b {
        $a.key.fc cmp $b.key.fc || $b.key cmp $a.key
    }).map: {
        (RakuAST::StrLiteral.new(.key), RakuAST::StrLiteral.new(.value)).Slip
          unless .key.ends-with('-' ~ .value)
    }

    # Found something to lookup in at runtime
    my $body := do if @operands {

        # Set up the constant hash
        $statements.add-statement: RakuAST::Statement::Expression.new(
          expression => RakuAST::VarDeclaration::Constant.new(
            scope       => "my",
            name        => "\%xlation",
            initializer => RakuAST::Initializer::Assign.new(
              RakuAST::ApplyListInfix.new(
                infix    => RakuAST::Infix.new(","),
                operands => @operands,
              )
            )
          )
        );

        # %translation{"$prefix-$key"} // $key
        RakuAST::StatementList.new(
          RakuAST::Statement::Expression.new(
            expression => RakuAST::ApplyInfix.new(
              left  => RakuAST::ApplyPostfix.new(
                operand => RakuAST::Var::Lexical.new("\%xlation"),
                postfix => RakuAST::Postcircumfix::HashIndex.new(
                  index => RakuAST::SemiList.new(
                    RakuAST::Statement::Expression.new(
                      expression => RakuAST::QuotedString.new(
                        segments   => (
                          RakuAST::Var::Lexical.new("\$prefix"),
                          RakuAST::StrLiteral.new("-"),
                          RakuAST::Var::Lexical.new("\$key"),
                        )
                      )
                    )
                  )
                )
              ),
              infix => RakuAST::Infix.new("//"),
              right => RakuAST::Var::Lexical.new("\$key")
            )
          )
        )
    }

    # Nothing to look up in, so just return $key
    else {
        RakuAST::Statement::Expression.new(
          expression => RakuAST::Var::Lexical.new("\$key")
        )
    }

    # Add method doing the actual mapping, basically:
    #
    # my role $language is export {
    #     my method xsyn(str $prefix, str $key) {
    #         $body
    #     }
    # }
    #
    $statements.add-statement: RakuAST::Statement::Expression.new(
      expression => RakuAST::Role.new(
        name => RakuAST::Name.from-identifier-parts(
                  'RakuAST','Deparse','L10N',$language
                ),
        body => RakuAST::RoleBody.new(
          body => RakuAST::Blockoid.new(
            RakuAST::StatementList.new(
              RakuAST::Statement::Expression.new(
                expression => RakuAST::Method.new(
                  name      => RakuAST::Name.from-identifier("xsyn"),
                  signature => RakuAST::Signature.new(
                    parameters => (
                      RakuAST::Parameter.new(
                        type   => RakuAST::Type::Simple.new(
                          RakuAST::Name.from-identifier("str")
                        ),
                        target => RakuAST::ParameterTarget::Var.new(
                          :name<$prefix>
                        )
                      ),
                      RakuAST::Parameter.new(
                        type   => RakuAST::Type::Simple.new(
                          RakuAST::Name.from-identifier("str")
                        ),
                        target => RakuAST::ParameterTarget::Var.new(
                          :name<$key>
                        )
                      ),
                    )
                  ),
                  body      => RakuAST::Blockoid.new(
                    RakuAST::StatementList.new($body)
                  )
                )
              )
            )
          )
        )
      )
    );

    $statements
}

#- update-localization-modules -------------------------------------------------
# Update the modules (L10N::xx RakuAST::Deparse::L10N::xx) for the
# given translation file
method update-localization-modules(IO() $io where *.extension eq $extension) {
    my $localization = $io.basename.subst(".$extension");
    my $root         = $io.sibling("lib");

    # Values for generating source files
    my $generator := $*PROGRAM.basename;
    my $generated := DateTime.now.gist.subst(/\.\d+/,'');
    my $start     := '#- start of generated part of localization';
    my $end       := '#- end of generated part of localization';

    my sub write-file(IO() $io, Str:D $src, Str:D $default) {

        # slurp the whole file and set up writing to it
        mkdir $io.parent;
        my @lines = ($io.e && $io.s ?? $io !! $default).lines;

        # for all the lines in the source that don't need special handling
        my $*OUT = $io.open(:w);
        while @lines {
            my $line := @lines.shift;

            # nothing to do yet
            unless $line.starts-with($start) {
                say $line;
                next;
            }

            say "$start ------------------------------------";
            say "#- Generated on $generated by $generator";
            say "#- PLEASE DON'T CHANGE ANYTHING BELOW THIS LINE";
            say "";

            # skip the old version of the code
            while @lines {
                last if @lines.shift.starts-with($end);
            }

            # Insert the actual logic
            print $src;

            # we're done for this role
            say "";
            say "#- PLEASE DON'T CHANGE ANYTHING ABOVE THIS LINE";
            say "$end --------------------------------------";
        }

        # close the file properly
        $*OUT.close;
    }

    # Create translation hash
    my %translation := self.read-hash($io, :core);

    # Create the slang and slangification
    my $slang  := self.slangify($localization, %translation);
    my $source := $slang.DEPARSE
      ~ Q:to/CODE/.subst('#LOCALIZATION#',$localization,:g);


# The EXPORT sub that actually does the slanging
my sub EXPORT($dontslang?) {
    unless $dontslang {
        my $LANG := $*LANG;
        $LANG.define_slang('MAIN',
          $LANG.slang_grammar('MAIN').^mixin(L10N::#LOCALIZATION#)
        );
    }

    BEGIN Map.new
}
CODE
    write-file
      $root.add(<<L10N "$localization.rakumod">>),
      $source,
      Q:to/DEFAULT/;
# This file contains the ……… Slang of the Raku Programming Language

#- start of generated part of localization
#- end of generated part of localization

# vim: expandtab shiftwidth=4
DEFAULT

    # Create the role for mixing in deparsing
    my $deparser := self.deparsify($localization, %translation);
    write-file
      $root.add(<<RakuAST Deparse L10N "$localization.rakumod">>),
      $deparser.DEPARSE,
      Q:to/DEFAULT/;
# This file contains the ……… deparsing logic for the Raku
# Programming Language.

#- start of generated part of localization
#- end of generated part of localization

# vim: expandtab shiftwidth=4
DEFAULT
}

#- INFORMATIONAL METHODS -------------------------------------------------------
method extensions-for-localization(Str:D $localization) {
    %extensions-for-localization{$localization} // Empty
      // unknown($localization)
}
method binaries-for-localization(Str:D $localization) {
    %binaries-for-localization{$localization}
      // unknown($localization)
}

method extension()     { $extension     }
method localizations() { @localizations }
method extensions()    { @extensions    }
method binaries()      { @binaries      }

# vim: expandtab shiftwidth=4
