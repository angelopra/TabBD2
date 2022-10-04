-- funcoes normais

-- Sabendo que a data de plantio e de colheita de uma plantação são tipos Date, e que o tempo de cultivo de uma cultura é um int, indicando o tempo em dias, a seguinte função calcula:
-- Quantos dias se passaram desde a plantação ter seu tempo de cultivo concluído, até o dia em que sua colheita foi concluída, a fim de saber o tempo que levou para colher esse plantio.
CREATE OR REPLACE FUNCTION tempo_para_colher(Colheita.idPlantio%TYPE, Colheita.seq_colheita%TYPE)
RETURNS int AS
$$
DECLARE
  dta_plantio Plantio.data%TYPE;
  temp_cultivo Cultura.tempo_cultivado%TYPE;
  dta_colheita Colheita.data%TYPE;
	cultura Cultura.idCultura%TYPE;
BEGIN
	SELECT data INTO dta_plantio FROM Plantio WHERE idPlantio = $1;
	SELECT idCultura INTO cultura	FROM Plantio WHERE idPlantio = $1;
	SELECT tempo_cultivado INTO temp_cultivo FROM Cultura WHERE idCultura = cultura;
	SELECT data INTO dta_colheita FROM Colheita WHERE idPlantio = $1 AND seq_colheita = $2;

	RETURN dta_colheita - (dta_plantio + temp_cultivo); -- tempo de cultivo é um int, medido em dias. Date + int -> Date. Então, Date - Date -> int, em dias
END;
$$
LANGUAGE 'plpgsql';


-- verifica se temos todos os inseticidas que combatem as pragas de uma cultura especificada
CREATE OR REPLACE FUNCTION ha_inseticidas_para_cultura(Cultura.idCultura%TYPE)
RETURNS boolean AS
$$
DECLARE
	praga_da_cultura Praga_Cultura.Praga%TYPE;
BEGIN
	FOR praga_da_cultura IN SELECT Praga FROM Praga_Cultura WHERE idCultura = $1 LOOP
		IF praga_da_cultura NOT IN SELECT combat_praga FROM Inseticida THEN
			RETURN FALSE;
		END IF;
	END LOOP;
	RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql';


-- calcula quantas sacas serao necessarias para uma colheita
CREATE OR REPLACE FUNCTION sacas_necess(Colheita.idPlantio%TYPE, Colheita.seq_colheita%TYPE, Saca.idRecColheita%TYPE)
RETURNS int AS
$$
DECLARE
	prod Colheita.producao%TYPE;
	tam_saca Saca.tamanho%TYPE;
BEGIN
	SELECT producao INTO prod FROM Colheita WHERE idPlantio = $1 AND seq_colheita = $2;
	SELECT tamanho INTO tam_saca FROM Saca WHERE idRecColheita = $3;
	RETURN prod/tam_saca;
END;
$$
LANGUAGE 'plpgsql';



-- triggers
    
-- ao atualizar as horas trab de usuario, atualiza o desempenho se for operador ou controlador
CREATE OR REPLACE FUNCTION atualiza_operador()
RETURNS trigger AS
$$
DECLARE
	operadores Operador.idUsuario%TYPE;
	controladores Controlador.idUsuario%TYPE;
BEGIN
	SELECT idUsuario INTO operadores FROM Operador;
	SELECT idUsuario INTO controladores FROM Controlador;
	IF NEW.idUsuario IN operadores THEN
		UPDATE Operador SET desempenho = NEW.hrs_trab/10 WHERE idUsuario = NEW.idUsuario;
	END IF;
	IF NEW.idUsuario IN controladores THEN
		UPDATE Controlador SET desempenho = NEW.hrs_trab/10 WHERE idUsuario = NEW.idUsuario;
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER tg_atualiza_operador AFTER UPDATE OF hrs_trab
ON Usuario FOR EACH ROW EXECUTE FUNCTION atualiza_operador()

    -- producao de uma colheita / tempo para colher = produtividade da colheitadeira. Atualize a produtividade dessa colheitadeira
    -- como sendo produtividade = (produtividade + nova produtividade) / 2

    -- antes de deletar uma tarefa, subtrai a data de emissa dela com a data atual (de deleção), verifica se o resultado é maior
    -- que o prazo, e se for, deleta o operador