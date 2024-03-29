(define <whitespace>
  (const
   (lambda (ch)
     (char<=? ch #\space))))
     
(define <line-comment>
  (let ((<end-of-line-comment>
	 (new (*parser (char #\newline))
	      (*parser <end-of-input>)
	      (*disj 2)
	      done)))
    (new (*parser (char #\;))
	 
	 (*parser <any-char>)
	 (*parser <end-of-line-comment>)
	 *diff *star

	 (*parser <end-of-line-comment>)
	 (*caten 3)
	 done)))

(define <sexpr-comment>
  (new (*parser (word "#;"))
       (*delayed (lambda () <sexpr>))
       (*caten 2)
       done))
       
(define <infix-comment>
  (new (*parser (word "#;"))
       (*delayed (lambda () <InfixExpression>))
       (*caten 2)
       done))

(define <comment>
  (disj <line-comment>
	<sexpr-comment>))
	
(define <comment-infix>
  (disj <line-comment>
	<infix-comment>))

(define <skip>
  (disj <comment>
	<whitespace>))
	
(define <skip-infix>
  (disj <comment-infix>
	<whitespace>))
	
(define times-4
  (lambda (<p>)
    (disj (times <p> 4) (times <p> 3) (times <p> 2) (times <p> 1))
  ))

(define ^^<wrapped>
  (lambda (<wrapper>)
    (lambda (<p>)
      (new (*parser <wrapper>)
	   (*parser <p>)
	   (*parser <wrapper>)
	   (*caten 3)
	   (*pack-with
	    (lambda (_left e _right) e))
	   done))))

(define ^<skipped*> (^^<wrapped> (star <skip>)))

(define ^<skipped-infix*> (^^<wrapped> (star <skip-infix>)))

(define <Boolean>
	(new    (*parser (char #\#))
	        (*parser (char-ci #\t))
	        (*caten 2)
	        (*parser (char #\#))
	        (*parser (char-ci #\f))
	        (*caten 2)
		(*disj 2)
		(*pack-with 
		  (lambda (a b)
		    (if (or (eq? b #\t) (eq? b #\T)) #t #f)))
        done))
	     
(define <CharPrefix>
      (new     (*parser (char #\#))
               (*parser (char #\\))
               (*caten 2)
       done))
       
(define <VisibleSimpleChar> (range #\! #\xff))

(define <NamedChar>
	(new    (*parser (word-ci "lambda"))
	        (*parser (word-ci "newline"))
            (*parser (word-ci "nul"))
            (*parser (word-ci "page")) 
	        (*parser (word-ci "return"))
	        (*parser (word-ci "space"))
	        (*parser (word-ci "tab"))
		(*disj 7) 
                (*pack
                  (lambda (a)
                    (cond ((equal? (list->string a) "lambda") #\x03bb)
                          ((equal? (list->string a) "newline") #\newline)
                          ((equal? (list->string a) "nul") #\nul)
                          ((equal? (list->string a) "page") #\page)
                          ((equal? (list->string a) "return") #\return)
                          ((equal? (list->string a) "space") #\space)
                          ((equal? (list->string a) "tab") #\tab)
                          (else ("error")))))
	     done))
	     
(define <HexChar>
	(new    (*parser (range #\0 #\9))
	        (*parser (range #\a #\f))
		    (*disj 2) 
	     done))
	     
(define <HexUnicodeChar>
	(new    (*parser (char-ci #\x))
	        (*parser (times-4 <HexChar>))
		    (*caten 2)
		    (*parser <HexChar>)
            *not-followed-by
		    (*pack-with (lambda (a b)
		       (integer->char (string->number (list->string b) 16))))
	     done))
	     
(define <SymbolChar>
        (new    (*parser (range #\0 #\9))
                (*parser (range #\a #\z))
                (*parser (range #\A #\Z))
                (*parser (char #\!))
                (*parser (char #\$))
                (*parser (char #\^))
                (*parser (char #\*))
                (*parser (char #\-))
                (*parser (char #\_))
                (*parser (char #\=))
                (*parser (char #\+))
                (*parser (char #\>))
                (*parser (char #\<))
                (*parser (char #\?))
                (*parser (char #\/))
                (*parser (char #\:))
                (*disj 16)
        done))	    

(define <Char>
	(new    (*parser <CharPrefix>)
            (*parser <NamedChar>)
            (*parser <HexUnicodeChar>)
	        (*parser <VisibleSimpleChar>)
	        (*parser <HexChar>)
            *not-followed-by
            (*disj 3)
            (*caten 2)
            (*pack-with (lambda (a b) b))
	     done))
	     
(define <Natural>
	(new    (*parser (range #\0 #\9)) *plus
	        (*pack (lambda (a)
	            (string->number (list->string a))))
         done))
	     
(define <Integer>
	(new    (*parser (char #\+))
            (*parser (char #\-))
		    (*disj 2)
		    (*parser <Natural>)
		    (*caten 2)
		    (*pack-with (lambda (a b)
		       (if (equal? a #\+) b (- b))))
		    (*parser <Natural>)
		    (*disj 2)
	     done))
	     
(define <Fraction>
	(new    (*parser <Integer>)
	        (*parser (char #\/))
		    (*parser <Natural>)
		    (*caten 3)
		    (*pack-with (lambda (a b c)
		        (/ a c)))
	     done))

(define <Number>
	(new   (*parser <Fraction>) 
	       (*parser <Integer>)
	       (*disj 2) 
	       (*parser <SymbolChar>)
	       (*parser <Natural>)
	       *diff
	       *not-followed-by
	     done))
	     
(define <StringVisibleChar> (diff <any-char> (char #\\)))
	     
(define <StringMetaChar>
	(new    (*parser (char #\\)) 
	        (*parser (char #\\)) 
		    (*parser (char #\"))
		    (*parser (char-ci #\t))
		    (*parser (char-ci #\f))
		    (*parser (char-ci #\n))
            (*parser (char-ci #\r))
		    (*disj 6)
		    (*caten 2)
		    (*pack-with (lambda (a b)
		         (cond ((equal? b #\\) #\\)
		               ((equal? b #\") #\")
		               ((or (equal? b #\t) (equal? b #\T)) #\tab)
		               ((or (equal? b #\f) (equal? b #\F)) #\xc)
		               ((or (equal? b #\n) (equal? b #\N)) #\xa)
		               ((or (equal? b #\r) (equal? b #\R)) #\xd))))
	     done))

(define <StringHexChar>
	(new    (*parser (char #\\))
            (*parser (char-ci #\x))
            (*caten 2)
		    (*parser (times-4 <HexChar>))
		    (*parser (char #\;))
            (*caten 3)
            (*pack-with (lambda (a b c)
                (integer->char (string->number (list->string b) 16))))
	     done))
	     
(define <StringChar>
        (new    (*parser <StringHexChar>)
                (*parser <StringMetaChar>)
                (*parser <StringVisibleChar>)
                (*disj 3)
             done))
	     
(define <String>
	(new    (*parser (char #\"))  
		    (*parser <StringChar>) (*parser (char #\")) *diff *star
		    (*parser (char #\"))
		    (*caten 3) 
		    (*pack-with (lambda (a b c)
		       (list->string b)))
	     done))	
	     
	     
(define <Symbol>
        (new    (*parser <SymbolChar>) *plus
                (*pack (lambda (a)
                    (string->symbol (string-downcase (list->string a)))))
        done))
	     
(define <ProperList>
        (new    (*parser (char #\())
                (*delayed (lambda () <sexpr>)) *star
                (*parser (char #\)))
                (*caten 3)
                (*pack-with (lambda (a b c) b))
        done))

(define <ImproperList>
        (new    (*parser (char #\())
                (*delayed (lambda () <sexpr>)) *plus
                (*parser (char #\.))
                (*delayed (lambda () <sexpr>))
                (*parser (char #\)))
                (*caten 5)
                (*pack-with (lambda (a b c d e)
                    `(,@b . ,d))
                        )
        done))
        
(define <Vector>
        (new    (*parser (char #\#))
                (*parser (char #\())
                (*delayed (lambda () <sexpr>)) *star
                (*parser (char #\)))
                (*caten 4)
                (*pack-with (lambda (a b c d)
                    (apply vector c)))
        done))
        
(define <Quoted>
        (new    (*parser (char #\'))
                (*delayed (lambda()  <sexpr>))
                (*caten 2)
                (*pack-with (lambda (a b)
                    `',b))
        done))
        
(define <QuasiQuoted>
        (new    (*parser (char #\`))
                (*delayed (lambda()  <sexpr>))
                (*caten 2)
                (*pack-with (lambda (a b)
                     (list 'quasiquote b)))
        done))
        
(define <Unquoted>
        (new    (*parser (char #\,))
                (*delayed (lambda()  <sexpr>))
                (*caten 2)
                (*pack-with (lambda (a b)
                     (list 'unquote b)))                
        done))        
        
(define <UnquotedAndSpliced>
        (new    (*parser (char #\,))
                (*parser (char #\@))
                (*delayed (lambda()  <sexpr>))
                (*caten 3)
                (*pack-with (lambda (a b c)
                     (list 'unquote-splicing c)))
        done))
        
(define last-elem (lambda (l) (car (reverse l))))

(define remove-last-elem (lambda (l) (reverse (cdr (reverse l)))))

(define char->symbol (lambda (a)
    (cond ((equal? a #\+) '+)
          ((equal? a #\-) '-)
          ((equal? a #\/) '/)
          ((equal? a #\*) '*))))

(define infix-pack-l (lambda (a b)
        (if (null? b) a
           (fold-left (lambda (x y) `(,(char->symbol (car y)) ,x ,(cadr y))) a b))))      
           
(define infix-pack-s-l (lambda (s)
    (lambda (a b)
        (if (null? b) a
           (fold-left (lambda (x y) `(,s ,x ,(cadr y))) a b)))))      

(define infix-pack-s-r (lambda (s)
     (lambda (a b)
        (if (null? b) a
           (let* ((b-values (map cadr b))
               (last-elem (last-elem b-values))
               (b-reduced (remove-last-elem b-values))
               (b-final (cons a b-reduced)))
             (fold-right (lambda (x y) `(,s ,x ,y)) last-elem b-final))))
        ))      
        
(define <InfixPrefixExtensionPrefix>
        (new    (*parser (char #\#))
                (*parser (char #\#))
                (*caten 2)
                (*parser (char #\#))
                (*parser (char #\%))
                (*caten 2)
                (*disj 2)
        done))
        
(define <InfixAddSub> 
       (new     (*delayed (lambda() <InfixMulDiv>))
                (*parser (char #\+))
                (*parser (char #\-))
                (*disj 2)
                (*delayed (lambda() <InfixMulDiv>))
                (*caten 2) *star
                (*caten 2)
                (*pack-with infix-pack-l)
        done))
        
(define <InfixMulDiv> 
       (new     (*delayed (lambda() <InfixPow>))
                (*parser (char #\*))
                (*parser (char #\/))
                (*disj 2)
                (*delayed (lambda() <InfixPow>))
                (*caten 2) *star
                (*caten 2)
                (*pack-with infix-pack-l)
        done))
        
(define <PowerSymbol>
       (new     (*parser (word "**"))
                (*parser (char #\^))
                (*disj 2)
        done))
        
(define <InfixPow> 
       (new     (*delayed (lambda() (^<skipped-infix*> <InfixFuncArray>)))
                (*parser <PowerSymbol>)
                (*delayed (lambda() (^<skipped-infix*> <InfixFuncArray>)))
                (*caten 2) *star
                (*caten 2)
                (*pack-with (infix-pack-s-r 'expt))
        done))
        
(define <InfixFuncArray>
       (new     (*delayed (lambda() <InfixLast>))
                (*parser (char #\[))
                (*delayed (lambda() <InfixExpression>))
                (*parser (char #\]))
                (*caten 3) 
                (*pack-with (lambda (a b c) (cons 'arr b)))
                (*parser (char #\())
                (*delayed (lambda() <InfixArgList>))
                (*parser (char #\)))
                (*caten 3) 
                (*pack-with (lambda (a b c) (cons 'func b)))
                (*disj 2)
                *star
                (*caten 2) 
                (*pack-with (lambda (a b)
                     (fold-left (lambda (x y)
                        (let ((y-op (car y))
                              (y (cdr y)))
                        (if (eq? y-op 'arr) 
                           `(vector-ref ,x ,y)
                           `(,x ,@y))))
                        a b)))
        done))
        
(define <InfixArrayGet> 
       (new     (*delayed (lambda() (^<skipped-infix*> <InfixFuncall>)))
                (*parser (char #\[))
                (*delayed (lambda() <InfixExpression>))
                (*parser (char #\]))
                (*caten 3) 
                *star
                (*parser <epsilon>)
                (*disj 2)
                (*caten 2) 
                (*pack-with (infix-pack-s-l 'vector-ref))
        done))
        
 (define <InfixFuncall>
       (new     (*delayed (lambda() <InfixLast>))
                (*parser (char #\())
                (*delayed (lambda() <InfixArgList>))
                (*parser (char #\)))
                (*caten 3)
                *star
                (*parser <epsilon>)
                (*disj 2)
                (*caten 2)
                (*pack-with (lambda (a b)
                    (if (null? b) a
                    (fold-left (lambda (x y) `(,x ,@(cadr y))) a b))))      
        done))
        
(define <InfixArgList>
        (new    (*delayed (lambda() <InfixExpression>))
                (*parser (char #\,))
                (*delayed (lambda() <InfixExpression>))
                (*caten 2) *star
                (*pack (lambda(a)
                            (map cadr a)))
                (*caten 2)
                (*pack-with (lambda(a b)
                                 (cons a b)))
                            
                (*parser (^<skipped-infix*> <epsilon>))
                (*disj 2)
        done))
        
 (define <InfixParen>
        (new    (*parser (char #\())
                (*delayed (lambda () <InfixExpression>))
                (*parser (char #\)))
                (*caten 3)
                (*pack-with (lambda (a b c) b))
        done)) 
        
(define <InfixSexprEscape>
        (new    (*delayed (lambda () <InfixPrefixExtensionPrefix>))
                (*delayed (lambda () <sexpr>))
                (*caten 2)
                (*pack-with (lambda (a b) b))
        done))
        
(define <InfixNeg>
        (new    (*parser (char #\-))
                (*delayed (lambda () <InfixFuncArray>))
                (*caten 2)
                (*pack-with (lambda (a b)
                    `(- ,b)))
        done))
        
(define <InfixLast>
        (new    (*parser (^<skipped-infix*> <InfixSexprEscape>))
                (*parser (^<skipped-infix*> <InfixParen>))
                (*delayed (lambda() (^<skipped-infix*> <InfixNumber>)))
                (*parser (^<skipped-infix*> <InfixNeg>))
                (*delayed (lambda() (^<skipped-infix*> <InfixSymbol>)))
                (*disj 5)
          done))
          
(define <InfixExpression> <InfixAddSub>)
        
(define <InfixSymbol>
        (new    (*parser <SymbolChar>) 
                (*parser (char #\+))
                (*parser (char #\-))
                (*parser (char #\*))
                (*parser (char #\^))
                (*parser (char #\/))
                (*parser (word "**"))
                (*disj 6) *diff *plus
                (*pack (lambda (a)
                    (string->symbol (string-downcase (list->string a)))))
        done))
        
(define <InfixNumber>
	(new   (*parser <Fraction>) 
	       (*parser <Integer>)
	       (*disj 2) 
	       (*parser <InfixSymbol>)
	       (*parser <Natural>)
	       *diff *not-followed-by
	     done))
        
(define <InfixExtension>
        (new    (*parser <InfixPrefixExtensionPrefix>)
                (*parser <InfixExpression>)
                (*caten 2)
                (*pack-with (lambda (a b)
                    b))
        done))
        
(define <sexpr> 
   (let* ((parsers (list <Boolean> <Char> <Number> <Symbol> <String> <ProperList>
                    <ImproperList> <Vector> <Quoted> <QuasiQuoted> <Unquoted>
                    <UnquotedAndSpliced> <InfixExtension>))
          (parsers-skipped (map ^<skipped*> parsers)))
         (apply disj parsers-skipped)
    ))

(define const-pattern-rule
     (lambda(pred)
        (pattern-rule
                (lambda (exp) (if (pred exp) (list exp) #f))
               (lambda(x) (list 'const x)))))


(define _boolean (const-pattern-rule boolean?))
(define _character (const-pattern-rule char?))
(define _number (const-pattern-rule number?))
(define _string (const-pattern-rule string?))
(define _vector (const-pattern-rule vector?))
(define _void (const-pattern-rule (lambda (x) (equal? (void) x))))

(define _quote
         (pattern-rule
              `(quote ,(? 'exp))
              (lambda (exp) `(const ,exp))))

(define _const
     (compose-patterns
          _vector
          _boolean
          _character
          _number
          _string
          _quote
          _void
            ))

(define *reserved-words*
    '(and begin cond define do else if lambda
    let let* letrec or quasiquote unquote
    unquote-splicing quote set!))

(define _var
        (pattern-rule
               (lambda (exp) (if (and (symbol? exp) (not (member exp *reserved-words*))) (list exp) #f))
               (lambda(x) (list 'var x))))

(define _if
   (compose-patterns
     (pattern-rule
          `(if ,(? 'test) ,(? 'then) ,(? 'else))
               (lambda (test then else)
               `(if3 ,(parse test) ,(parse then) ,(parse else))))
     (pattern-rule
          `(if ,(? 'test) ,(? 'then))
               (lambda (test then)
               `(if3 ,(parse test) ,(parse then) ,(parse (void)))))))

(define _or
     (pattern-rule
          `(or . ,(? 'bodies))
               (lambda (bodies)
               (cond ((null? bodies) (parse '#f))
                     ((eq? (length bodies) 1) (parse (car bodies)))
                     (else `(or ,(map parse bodies)))))))

(define _and
     (pattern-rule
          `(and . ,(? 'bodies))
               (lambda (bodies)
               (cond ((null? bodies) (parse '#t))
                     ((eq? (length bodies) 1) (parse (car bodies)))
                     (else (parse `(if ,(car bodies) (and ,@(cdr bodies)) #f)))))))

(define improper-list-last
        (lambda(l)
            (if (pair? l) (improper-list-last (cdr l)) l)))

(define improper-list-remove-last
        (lambda(l)
            (if (pair? l)
                  (cons (car l) (improper-list-remove-last (cdr l)))
                    '())))

(define remove-duplicates
     (lambda (l)
        (cond ((null? l) '())
            ((member (car l) (cdr l)) (remove-duplicates (cdr l)))
            (else (cons (car l) (remove-duplicates (cdr l)))))))

(define is-distinct
    (lambda (x)
        (equal? (length (remove-duplicates x)) (length x))))

(define _lambda
     (pattern-rule
          `(lambda ,(? 'params) . ,(? 'bodies))
               (lambda (params bodies)
                         (if (and (list? params) (not (is-distinct params)))
                            (error 'parse "Repeating lambda params!")
                            (let ((bodies (map parse bodies))
                              (new-params (improper-list-remove-last params))
                              (seq (parse `(begin ,@bodies))))
                                (cond ((list? params) `(lambda-simple ,params ,seq))
                                   ((pair? params) `(lambda-opt ,new-params ,(improper-list-last params) ,seq))
                                   (else `(lambda-var ,params ,seq))))))))

(define _define
      (pattern-rule
          `(define ,(? 'var) . ,(? 'def))
               (lambda (var def)
                  (if (pair? var)
                  (let ((exp (parse `(lambda ,(cdr var) ,@def))))
                    `(def ,(parse (car var)) ,exp))
                    (let ((def (parse `(begin ,@def))))
                      `(def ,(parse var) ,def))))))

(define _application
      (pattern-rule
          `(,(? 'func) . ,(? 'params))
               (lambda (func params)
                  (if (null? func)
                     (error 'done (format "Unknown form: ~s" func))
                     (let ((func (parse func))
                        (params (map parse params)))
                        `(applic ,func ,params))))))

(define _cond
      (pattern-rule
          `(cond . ,(? 'bodies))
               (lambda (bodies)
                    (cond ((null? bodies) (error 'parse "Unknown form: (cond)"))
                          ((eq? (caar bodies) 'else) (parse `(begin ,@(cdar bodies))))
                          ((eq? (length bodies) 1) (parse `(if ,(caar bodies) (begin ,@(cdar bodies)))))
                          (else (parse `(if ,(caar bodies) (begin ,@(cdar bodies)) (cond ,@(cdr bodies)))))))))

(define remove-seq
   (lambda (bodies)
       (cond ((null? bodies) bodies)
             ((and (list? (car bodies)) (equal? (caar bodies) 'seq))
                 (append (car (cdar bodies)) (remove-seq (cdr bodies))))
             (else (cons (car bodies) (remove-seq (cdr bodies)))))))


(define _begin
      (pattern-rule
          `(begin . ,(? 'bodies))
               (lambda (bodies)
                  (let* ((bodies (map parse bodies))
                         (bodies (remove-seq bodies)))
                    (cond ((null? bodies) (parse (void)))
                         ((eq? (length bodies) 1) (car bodies))
                         (else `(seq ,bodies)))))))

(define _let
      (pattern-rule
          `(let ,(? 'params) . ,(? 'bodies))
               (lambda (params bodies)
                      (parse `((lambda ,(map car params) ,@bodies)  ,@(map cadr params))))))

(define _let*
      (pattern-rule
          `(let* ,(? 'params) . ,(? 'bodies))
               (lambda (params bodies)
                      (cond ((null? params)(parse `(let ,params ,@bodies)))
                            ((eq? (length params) 1) (parse `(let ,params ,@bodies)))
                            (else (parse `(let ,(list (car params)) (let* ,(cdr params) ,@bodies))))))))

(define _letrec
      (pattern-rule
          `(letrec ,(? 'params) . ,(? 'bodies))
               (lambda (params bodies)
                    (let ((set-bodies (map (lambda (x y) `(set! ,x ,y))
                                       (map car params) (map cadr params)))
                          (false-params (map (lambda (x y) `(,x #f))
                                           (map car params) (map cadr params)))
                          (let-bodies `((let () ,@bodies))))
                         (parse `(let ,false-params ,@(append set-bodies let-bodies)))))))

(define _set!
     (pattern-rule
          `(set! ,(? 'arg) ,(? 'val))
             (lambda (arg val)
                 `(set ,(parse arg) ,(parse val)))))

(define _quasiquote
     (pattern-rule
             (lambda (exp) (if (eq? (car exp) 'quasiquote) (cdr exp) #f))
             (lambda (exp)
                 (parse (expand-qq exp)))))


(define ^quote?
  (lambda (tag)
    (lambda (e)
      (and (pair? e)
	   (eq? (car e) tag)
	   (pair? (cdr e))
	   (null? (cddr e))))))

(define quote? (^quote? 'quote))
(define unquote? (^quote? 'unquote))
(define unquote-splicing? (^quote? 'unquote-splicing))

(define const?
  (let ((simple-sexprs-predicates
	 (list boolean? char? number? string?)))
    (lambda (e)
      (or (ormap (lambda (p?) (p? e))
		 simple-sexprs-predicates)
	  (quote? e)))))

(define quotify
  (lambda (e)
    (if (or (null? e)
	    (pair? e)
	    (symbol? e)
	    (vector? e))
	`',e
	e)))

(define unquotify
  (lambda (e)
    (if (quote? e)
	(cadr e)
	e)))

(define const-pair?
  (lambda (e)
    (and (quote? e)
	 (pair? (cadr e)))))

(define expand-qq
  (letrec ((expand-qq
	    (lambda (e)
	      (cond ((unquote? e) (cadr e))
		    ((unquote-splicing? e)
		     (error 'expand-qq
		       "unquote-splicing here makes no sense!"))
		    ((pair? e)
		     (let ((a (car e))
			   (b (cdr e)))
		       (cond ((unquote-splicing? a)
			      `(append ,(cadr a) ,(expand-qq b)))
			     ((unquote-splicing? b)
			      `(cons ,(expand-qq a) ,(cadr b)))
			     (else `(cons ,(expand-qq a) ,(expand-qq b))))))
		    ((vector? e) `(list->vector ,(expand-qq (vector->list e))))
		    ((or (null? e) (symbol? e)) `',e)
		    (else e))))
	   (optimize-qq-expansion (lambda (e) (optimizer e (lambda () e))))
	   (optimizer
	    (compose-patterns
	     (pattern-rule
	      `(append ,(? 'e) '())
	      (lambda (e) (optimize-qq-expansion e)))
	     (pattern-rule
	      `(append ,(? 'c1 const-pair?) (cons ,(? 'c2 const?) ,(? 'e)))
	      (lambda (c1 c2 e)
		(let ((c (quotify `(,@(unquotify c1) ,(unquotify c2))))
		      (e (optimize-qq-expansion e)))
		  (optimize-qq-expansion `(append ,c ,e)))))
	     (pattern-rule
	      `(append ,(? 'c1 const-pair?) ,(? 'c2 const-pair?))
	      (lambda (c1 c2)
		(let ((c (quotify (append (unquotify c1) (unquotify c2)))))
		  c)))
	     (pattern-rule
	      `(append ,(? 'e1) ,(? 'e2))
	      (lambda (e1 e2)
		(let ((e1 (optimize-qq-expansion e1))
		      (e2 (optimize-qq-expansion e2)))
		  `(append ,e1 ,e2))))
	     (pattern-rule
	      `(cons ,(? 'c1 const?) (cons ,(? 'c2 const?) ,(? 'e)))
	      (lambda (c1 c2 e)
		(let ((c (quotify (list (unquotify c1) (unquotify c2))))
		      (e (optimize-qq-expansion e)))
		  (optimize-qq-expansion `(append ,c ,e)))))
	     (pattern-rule
	      `(cons ,(? 'e1) ,(? 'e2))
	      (lambda (e1 e2)
		(let ((e1 (optimize-qq-expansion e1))
		      (e2 (optimize-qq-expansion e2)))
		  (if (and (const? e1) (const? e2))
		      (quotify (cons (unquotify e1) (unquotify e2)))
		      `(cons ,e1 ,e2))))))))
    (lambda (e)
      (optimize-qq-expansion
       (expand-qq e)))))



(define parse
 (let ((run
  (compose-patterns
     _const
     _var
     _cond
     _if
     _or
     _and
     _lambda
     _define
     _begin
     _let
     _let*
     _letrec
     _set!
     _quasiquote
     _application
     )))
  (lambda (sexpr)
        (run sexpr (lambda () "Exception in parser")))))

(define eliminate-nested-defines-helper
       (lambda(parsed-expr)
           (cond ((null? parsed-expr) (cons '() '()))
                 ((is-lambda? (car parsed-expr)) (cons '() (list parsed-expr)))
                 ((list? (car parsed-expr))
                    (let ((res1 (eliminate-nested-defines-helper (car parsed-expr)))
                          (res2 (eliminate-nested-defines-helper (cdr parsed-expr))))
                       (cons (append (car res1) (car res2)) (append (cdr res1) (cdr res2)))))
                 ((eq? (car parsed-expr) 'def) (cons (list parsed-expr) '()))
                 ((eq? (car parsed-expr) 'seq) (eliminate-nested-defines-helper (cadr parsed-expr)))
                 (else (cons '() (list parsed-expr))))))

(define is-set?
      (lambda(e) (and (eq? (car e) 'set) (eq? (length e) 3))))

(define is-lambda?
      (lambda(e) (or (eq? e 'lambda-simple) (eq? e 'lambda-var) (eq? e 'lambda-opt))))

(define lambda-get-def
      (lambda(e)
          (car e)))

(define lambda-get-params
      (lambda(e)
          (remove-last-elem (cdr e))))

(define lambda-get-listed-params
      (lambda(e)
          (letrec ((convert-to-list (lambda (x)
                (if (null? x)
                     x
                     (if (list? (car x))
                        (append (car x) (convert-to-list (cdr x)))
                        (append (list (car x)) (convert-to-list (cdr x))))))))
                  (convert-to-list (lambda-get-params e)))))

(define lambda-get-body
      (lambda(e)
          (last e)))

(define eliminate-nested-defines
      (lambda(parsed-expr)
          (cond ((null? parsed-expr) `())
                ((list? (car parsed-expr))
                   (cons (eliminate-nested-defines (car parsed-expr))
                         (eliminate-nested-defines (cdr parsed-expr))))
                ((is-lambda? (car parsed-expr))
                    (let* ((lambda-def (lambda-get-def parsed-expr))
                           (body (eliminate-nested-defines (lambda-get-body parsed-expr)))
                           (params (lambda-get-params parsed-expr))
                           (res (eliminate-nested-defines-helper body))
                           (ds (car res))
                           (es (cdr res)))
                                (if (null? ds)
                                   `(,lambda-def ,@params ,body)
                                   (let* ((vars (map cadadr ds))
                                          (vals (map caddr ds))
                                          (applic-args (map (lambda (x) '(const #f)) vars))
                                          (let-sets (map (lambda (var val) `(set (var ,var) ,val)) vars vals))
                                          (let-body (append let-sets es)))
                                      `(,lambda-def ,@params
                                         (applic (lambda-simple ,vars (seq ,let-body)) ,applic-args))))))
                (else (cons (car parsed-expr) (eliminate-nested-defines (cdr parsed-expr)))))))

(define applic-lambda-nil?
   (lambda(e)
   (and (eq? (car e) 'applic)
        (eq? 'lambda-simple (caadr e))
        (null? (cadadr e))
        (null? (caddr e)))))

(define remove-applic-lambda-nil
      (lambda(parsed-expr)
          (cond ((null? parsed-expr) `())
                ((applic-lambda-nil? parsed-expr)
                   (remove-applic-lambda-nil (car (cddadr parsed-expr))))
                ((list? (car parsed-expr))
                   (cons (remove-applic-lambda-nil (car parsed-expr))
                         (remove-applic-lambda-nil (cdr parsed-expr))))
                (else (cons (car parsed-expr) (remove-applic-lambda-nil (cdr parsed-expr)))))))

(define index
     (lambda(var lst)
        (letrec ((index-helper
           (lambda(var lst counter)
             (cond ((null? lst) -1)
                   ((eq? (car lst) var) counter)
                   (else (index-helper var (cdr lst) (+ counter 1)))))))
            (index-helper var lst 0))))

(define find-var-in-acc
    (lambda(var acc)
      (find-var-in-acc-helper var acc 0)))

(define find-var-in-acc-helper
    (lambda(var acc counter)
       (if (null? acc)
          `(fvar ,var)
          (let ((minor (index var (car acc))))
             (cond ((eq? minor -1) (find-var-in-acc-helper var (cdr acc) (+ counter 1)))
                   (else (if (eq? counter 0)
                      `(pvar ,var ,minor)
                      `(bvar ,var ,(- counter 1) ,minor))))))))

(define pe->lex-pe
      (lambda(parsed-expr)
          (pe->lex-pe-helper parsed-expr '())))

(define pe->lex-pe-helper
      (lambda(parsed-expr acc)
          (cond ((or (not (list? parsed-expr)) (null? parsed-expr)) parsed-expr)
                ((list? (car parsed-expr))
                  (cons (pe->lex-pe-helper (car parsed-expr) acc) (pe->lex-pe-helper (cdr parsed-expr) acc)))
                ((is-lambda? (car parsed-expr))
                   (let* ((lambda-def (lambda-get-def parsed-expr))
                          (params (lambda-get-params parsed-expr))
                          (listed-params (lambda-get-listed-params parsed-expr))
                          (body (lambda-get-body parsed-expr)))
                       `(,lambda-def ,@params ,(pe->lex-pe-helper body (cons listed-params acc)))))
                ((eq? (car parsed-expr) 'var) (find-var-in-acc (cadr parsed-expr) acc))
                (else (cons (car parsed-expr) (pe->lex-pe-helper (cdr parsed-expr) acc))))))

(define last
   (lambda(lst)
      (if (eq? (length lst) 1)
         (car lst)
         (last (cdr lst)))))

(define replace-last
   (lambda(lst var)
      (if (eq? (length lst) 1)
         (list var)
         (cons (car lst) (replace-last (cdr lst) var)))))

(define annotate-last-elem
    (lambda(elem)
       (cond ((not (list? elem)) elem)
             ((eq? (car elem) 'applic) (cons 'tc-applic (cdr elem)))
             ((eq? (car elem) 'if3)
                (let ((condition (cadr elem))
                      (dit (caddr elem))
                      (dif (cadddr elem)))
                    `(if3  ,condition ,(annotate-last-elem dit) ,(annotate-last-elem dif))))
             ((member (car elem) '(or seq))
                (let* ((operator (car elem))
                       (body (cadr elem))
                       (new-last (annotate-last-elem (last body)))
                       (new-body (replace-last body new-last)))
                   `(,operator ,new-body)))
             (else elem))))

(define annotate-tc
      (lambda(parsed-expr)
          (cond ((or (not (list? parsed-expr)) (null? parsed-expr)) parsed-expr)
                ((list? (car parsed-expr))
                  (cons (annotate-tc (car parsed-expr)) (annotate-tc (cdr parsed-expr))))
                ((is-lambda? (car parsed-expr))
                    (let* ((lambda-def (lambda-get-def parsed-expr))
                           (params (lambda-get-params parsed-expr))
                           (body (annotate-tc (lambda-get-body parsed-expr)))
                           (new-body (annotate-last-elem body)))
                        `(,lambda-def ,@params ,new-body)))
                (else (cons (car parsed-expr) (annotate-tc (cdr parsed-expr)))))))

(define box-set
   (lambda(parsed-expr)
          (cond ((or (not (list? parsed-expr)) (null? parsed-expr)) parsed-expr)
                ((list? (car parsed-expr))
                  (cons (box-set (car parsed-expr)) (box-set (cdr parsed-expr))))
                ((is-lambda? (car parsed-expr))
                    (box-set-helper parsed-expr))
                (else (cons (car parsed-expr) (box-set (cdr parsed-expr)))))))

(define fix-order
      (lambda (lst order)
           (fold-right (lambda (mem acc) (if (member mem lst) (cons mem acc) acc)) (list) order)))

(define box-set-helper
   (lambda(parsed-expr)
          (let* ((lambda-def (lambda-get-def parsed-expr))
                 (params (lambda-get-params parsed-expr))
                 (body (box-set (lambda-get-body parsed-expr)))
                 (listed-params (lambda-get-listed-params parsed-expr))
                 (set-vars (remove-duplicates (find-set-vars body '())))
                 (get-vars (remove-duplicates (find-get-vars body (list listed-params) '())))
                 (bound-vars (remove-duplicates (find-bound-vars body (list listed-params) '())))
                 (params-in-vars (map (lambda (x) `(var ,x)) listed-params))
                 (vars-to-fix (fix-order (member-in-three set-vars get-vars bound-vars) params-in-vars)))
              (if (null? vars-to-fix)
                  `(,lambda-def ,@params ,body)
                  (let* ((set-exprs (map (lambda (x) `(set ,x (box ,x))) vars-to-fix))
                         (fixed-body (box-set-vars body vars-to-fix))
                         (new-body (if (eq? (car fixed-body) 'seq)
                            `(seq ,(append set-exprs (cadr fixed-body)))
                            `(seq ,(append set-exprs (list fixed-body))))))
                     `(,lambda-def ,@params ,new-body))))))


(define find-set-vars
   (lambda(parsed-expr acc)
          (cond ((or (not (list? parsed-expr)) (null? parsed-expr)) acc)
                ((list? (car parsed-expr))
                  (append (find-set-vars (car parsed-expr) acc) (find-set-vars (cdr parsed-expr) acc)))
                ((is-lambda? (car parsed-expr))
                   (let* ((lambda-def (lambda-get-def parsed-expr))
                          (listed-params (lambda-get-listed-params parsed-expr))
                          (body (lambda-get-body parsed-expr))
                          (var-listed-params (map (lambda(x) `(var ,x)) listed-params))
                          (res (find-set-vars body acc)))
                       (append (remove-from-list res var-listed-params) acc)))
                ((is-set? parsed-expr)
                    (cons (cadr parsed-expr) (find-set-vars (caddr parsed-expr) acc)))
                (else (find-set-vars (cdr parsed-expr) acc)))))

(define find-get-vars
   (lambda(parsed-expr params-acc acc)
          (cond ((or (not (list? parsed-expr)) (null? parsed-expr)) acc)
                ((list? (car parsed-expr))
                  (append (find-get-vars (car parsed-expr) params-acc acc) (find-get-vars (cdr parsed-expr) params-acc acc)))
                ((is-lambda? (car parsed-expr))
                   (let* ((lambda-def (lambda-get-def parsed-expr))
                          (listed-params (lambda-get-listed-params parsed-expr))
                          (body (lambda-get-body parsed-expr))
                          (var-listed-params (map (lambda(x) `(var ,x)) listed-params))
                          (res (find-get-vars body (cons listed-params params-acc) acc)))
                       (append (remove-from-list res var-listed-params) acc)))
                ((is-set? parsed-expr)
                   (append (find-get-vars (cddr parsed-expr) params-acc acc) acc))
                ((eq? (car parsed-expr) 'var)
                   (let ((tagged-var (find-var-in-acc (cadr parsed-expr) params-acc)))
                       (if (or (eq? (car tagged-var) 'bvar) (eq? (car tagged-var) 'pvar))
                           (cons parsed-expr acc)
                           acc)))
                (else (find-get-vars (cdr parsed-expr) params-acc acc)))))

(define find-bound-vars
   (lambda(parsed-expr params-acc acc)
          (cond ((or (not (list? parsed-expr)) (null? parsed-expr)) acc)
                ((list? (car parsed-expr))
                  (append (find-bound-vars (car parsed-expr) params-acc acc) (find-bound-vars (cdr parsed-expr) params-acc acc)))
                ((is-lambda? (car parsed-expr))
                   (let* ((lambda-def (lambda-get-def parsed-expr))
                          (listed-params (lambda-get-listed-params parsed-expr))
                          (body (lambda-get-body parsed-expr))
                          (var-listed-params (map (lambda(x) `(var ,x)) listed-params))
                          (res (find-bound-vars body (cons listed-params params-acc) acc)))
                       (append (remove-from-list res var-listed-params) acc)))
                ((eq? (car parsed-expr) 'var)
                   (let ((tagged-var (find-var-in-acc (cadr parsed-expr) params-acc)))
                       (if (eq? (car tagged-var) 'bvar)
                           (cons parsed-expr acc)
                           acc)))
                (else (find-bound-vars (cdr parsed-expr) params-acc acc)))))

(define member-in-three
    (lambda (l1 l2 l3)
        (fold-right (lambda (mem acc) (if (and (member mem l2) (member mem l3)) (cons mem acc) acc)) (list) l1)))

(define remove-from-list
    (lambda (lst vars-to-remove)
        (cond ((null? lst) lst)
              ((member (car lst) vars-to-remove) (remove-from-list (cdr lst) vars-to-remove))
              (else (cons (car lst) (remove-from-list (cdr lst) vars-to-remove))))))

(define box-set-vars
    (lambda(parsed-expr vars-to-fix)
         (cond ((or (not (list? parsed-expr)) (null? parsed-expr)) parsed-expr)
                ((list? (car parsed-expr))
                  (cons (box-set-vars (car parsed-expr) vars-to-fix) (box-set-vars (cdr parsed-expr) vars-to-fix)))
                ((and (is-set? parsed-expr) (member (cadr parsed-expr) vars-to-fix))
                  `(box-set ,(cadr parsed-expr) ,@(box-set-vars (cddr parsed-expr) vars-to-fix)))
                ((and (eq? (car parsed-expr) 'var) (member parsed-expr vars-to-fix))
                  `(box-get ,parsed-expr))
                ((is-lambda? (car parsed-expr))
                   (let ((lambda-def (lambda-get-def parsed-expr))
                         (body (lambda-get-body parsed-expr))
                         (params (lambda-get-params parsed-expr))
                         (listed-params (map (lambda(x) `(var ,x)) (lambda-get-listed-params parsed-expr))))
                   `(,lambda-def ,@params ,(box-set-vars body (remove-from-list vars-to-fix listed-params)))))
                (else (cons (car parsed-expr) (box-set-vars (cdr parsed-expr) vars-to-fix))))))

(define run (lambda (x)
		    (annotate-tc
		      (pe->lex-pe
			(box-set
			  (remove-applic-lambda-nil
			    (eliminate-nested-defines (parse x))))))))